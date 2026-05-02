// ─────────────────────────────────────────────────────────────────────────────
// 카메라(뽀모도로) 페이지
//
// 흐름:
//   - _selectedTask == null  → 가운데 "과목을 선택해주세요" 안내
//   - _selectedTask != null  → 원형 카운트다운 타이머 + 자동 세션 시작
//
// 타이머:
//   - 기본 25분 / 휴식 5분 (이게 최저값, 늘리기만 가능)
//   - 가운데 원 탭 → 시간 변경 다이얼로그
//   - 일시정지 / 재개, 리셋 가능
//   - 0초 도달 시 세션 종료(mock 점수 저장) → 휴식 모드로 전환
//
// 카메라:
//   - 우측 영역에 셀카 프리뷰 (face detection / ML 없음)
//   - 상태(집중/비집중)는 일단 placeholder. ML 붙은 후 채움.
//
// 점수:
//   - mock 0.65 유지 (FSRS 흐름 보존)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/study_session.dart';
import '../providers/study_session_provider.dart';
import '../widgets/concentration_service.dart';

// ── 상수 ──────────────────────────────────────────────────────────────────────
// 동적 추천 정책 기준값
//   - debug 빌드: 1분 / 1분 (개발 테스트용 — flutter run 시 자동 적용)
//   - release 빌드: 25분 / 5분 (실제 사용자용 — flutter build 시 자동 적용)
//   → 발표/배포는 release 빌드로
const int _kMinFocusMinutes = kDebugMode ? 1 : 25;
const int _kMinBreakMinutes = kDebugMode ? 1 : 5;
const int _kMaxFocusMinutes = 180;
const int _kMaxBreakMinutes = 60;

const int _kDefaultFocusMinutes = kDebugMode ? 1 : 25;
const int _kDefaultBreakMinutes = kDebugMode ? 1 : 5;

const Color _kAccent = Color(0xFFD97068);
const Color _kAccentDark = Color(0xFFB34C3D);

// 다이얼로그 칩 프리셋 (모두 최저값 이상)
const List<int> _kFocusPresets = [25, 30, 45, 60, 90];
const List<int> _kBreakPresets = [5, 10, 15, 20, 30];

/// 카메라 화면에서 사용하는 할일 단위
class CameraTask {
  final String todoId;
  final String goalId;
  final String subjectId;
  final String text;
  final String? subjectName; // "과목 - 할일" 표시용
  final Color? subjectColor; // 과목별 색 (동그라미/게이지에 적용)

  const CameraTask({
    required this.todoId,
    required this.goalId,
    required this.subjectId,
    required this.text,
    this.subjectName,
    this.subjectColor,
  });

  /// "과목 - 할일" 또는 과목명 없으면 그냥 "할일"
  String get displayLabel {
    final n = subjectName;
    if (n == null || n.trim().isEmpty) return text;
    return '$n - $text';
  }

  /// 색 fallback (지정 안 됐으면 기본 액센트)
  Color get color => subjectColor ?? _kAccent;
}

class CameraPage extends ConsumerStatefulWidget {
  final CameraTask? initialSelectedTask;
  final List<CameraTask> allTasks;

  const CameraPage({
    super.key,
    required this.initialSelectedTask,
    required this.allTasks,
  });

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  // ── 과목 / 세션 ──────────────────────────────────────────────────────────
  CameraTask? _selectedTask;
  late Map<String, bool> _doneMap; // todoId → done
  StudySession? _activeSession;

  // ── 타이머 ────────────────────────────────────────────────────────────────
  bool _isBreakMode = false; // false = 집중 / true = 휴식
  int _focusMinutes = _kDefaultFocusMinutes; // 사용자 설정값 (집중)
  int _breakMinutes = _kDefaultBreakMinutes; // 사용자 설정값 (휴식)
  int _remainingSeconds = _kDefaultFocusMinutes * 60;
  bool _isRunning = false;
  Timer? _ticker;

  int get _totalSeconds => (_isBreakMode ? _breakMinutes : _focusMinutes) * 60;

  // ── 카메라 ────────────────────────────────────────────────────────────────
  CameraController? _camCtrl;
  bool _camReady = false;
  String? _camError;

  // ── 집중도 측정 ───────────────────────────────────────────────────────────
  final ConcentrationService _service = ConcentrationService();
  bool _serviceReady = false;
  int _frameCounter = 0; // 매 5번째 프레임만 처리 (≈ 6fps)

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialSelectedTask;
    _doneMap = {for (final t in widget.allTasks) t.todoId: false};
    if (_selectedTask != null) {
      _startSession(_selectedTask!);
      // 타이머는 사용자가 ▶ 버튼을 누를 때만 시작 (자동 시작 X)
    }
    _initCamera();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // image stream 멈추고 카메라/서비스 해제
    if (_camCtrl?.value.isStreamingImages ?? false) {
      _camCtrl!.stopImageStream();
    }
    _camCtrl?.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── 카메라 초기화 ────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _camError = '사용 가능한 카메라 없음');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit 은 iOS BGRA8888, Android NV21 가 권장 포맷
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _camCtrl = ctrl;
        _camReady = true;
      });

      // ConcentrationService 초기화 + image stream 시작
      try {
        await _service.initialize();
        if (!mounted) return;
        _serviceReady = true;
        debugPrint('[camera_page] ConcentrationService 준비 완료');

        await ctrl.startImageStream(_onCameraImage);
      } catch (e) {
        debugPrint('[camera_page] 집중도 서비스 초기화 실패: $e');
        // 실패해도 카메라 프리뷰는 그대로 동작
      }
    } catch (e) {
      if (mounted) setState(() => _camError = '카메라 오류: $e');
    }
  }

  /// 카메라 image stream 콜백 — 타이머 실행 중 + 집중 모드일 때만 측정
  /// ML Kit 은 InputImage 의 rotation metadata 로 회전 자동 처리
  void _onCameraImage(CameraImage image) {
    if (!_serviceReady) return;
    if (!_isRunning || _isBreakMode) return;
    _frameCounter++;
    if (_frameCounter % 3 != 0) return; // 10fps 처리 (깜빡임 캡처용)

    final sensorOri = _camCtrl?.description.sensorOrientation ?? 0;

    if (_frameCounter == 3) {
      debugPrint('[camera_page] 첫 processFrame 호출 — '
          '${image.width}x${image.height} format=${image.format.raw} '
          'sensorOri=$sensorOri');
    }

    _service.processFrame(image, sensorOrientation: sensorOri);
  }

  // ── 세션 ──────────────────────────────────────────────────────────────────
  Future<void> _startSession(CameraTask task) async {
    if (task.goalId.isEmpty) return;
    _activeSession =
        await ref.read(studySessionProvider.notifier).startSession(task.goalId);
  }

  Future<void> _endSession() async {
    if (_activeSession == null || _selectedTask == null) return;
    // ConcentrationService 가 누적한 평균 점수 (0~1).
    // 측정 데이터가 없으면 0.65 fallback (mock 과 동일한 Good 등급)
    final focusScore = _serviceReady ? _service.averageScore01 : 0.65;
    await ref.read(studySessionProvider.notifier).endSession(
          session: _activeSession!,
          focusScore: focusScore,
          subjectId: _selectedTask!.subjectId,
        );
    _activeSession = null;
  }

  // ── 타이머 제어 ──────────────────────────────────────────────────────────
  void _startTimer() {
    _ticker?.cancel();
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _onTimerComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _toggleRunning() {
    if (_selectedTask == null) return;
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _resetTimer() {
    _ticker?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
    });
  }

  Future<void> _onTimerComplete() async {
    _ticker?.cancel();
    if (_isBreakMode) {
      // 휴식 끝 → 집중 모드로 (수동 ▶ 대기)
      // 카메라 image stream 재시작 (휴식 동안 멈춰있었음)
      if (_camCtrl != null && !(_camCtrl!.value.isStreamingImages)) {
        await _camCtrl!.startImageStream(_onCameraImage);
      }
      setState(() {
        _isBreakMode = false;
        _remainingSeconds = _focusMinutes * 60;
        _isRunning = false;
      });
    } else {
      // 집중 끝 → 점수 저장 → 평가 팝업 → 추천 적용 → 휴식 자동 시작
      final avgScore01 =
          _serviceReady ? _service.averageScore01 : 0.65;
      final avgScore = (avgScore01 * 100).clamp(0.0, 100.0);

      // 추천 다음 세션 시간 계산
      final rec = _serviceReady
          ? _service.recommendNextSession(
              currentFocusMinutes: _focusMinutes,
              maxFocusMinutes: _kMaxFocusMinutes,
              minFocusMinutes: _kMinFocusMinutes,
              minBreakMinutes: _kMinBreakMinutes,
            )
          : (focusMinutes: _focusMinutes, breakMinutes: _breakMinutes);

      // 세션 종료 (DB 저장 + FSRS 갱신)
      await _endSession();
      if (!mounted) return;

      // 평가 팝업 (확인 누를 때까지 대기)
      await showDialog(
        context: context,
        barrierDismissible: false, // 외부 탭 무시
        builder: (ctx) => _SessionEvalDialog(
          avgScore: avgScore,
          recommendedFocusMinutes: rec.focusMinutes,
          recommendedBreakMinutes: rec.breakMinutes,
          currentFocusMinutes: _focusMinutes,
        ),
      );
      if (!mounted) return;

      // 추천 적용 + 다음 세션을 위한 service reset
      if (_serviceReady) _service.reset();
      if (_selectedTask != null) await _startSession(_selectedTask!);
      if (!mounted) return;

      // 휴식 모드 진입 — 카메라 image stream 멈춤 (CPU 절약)
      if (_camCtrl?.value.isStreamingImages ?? false) {
        await _camCtrl!.stopImageStream();
      }

      setState(() {
        _focusMinutes = rec.focusMinutes;     // 다음 집중 시간 적용
        _breakMinutes = rec.breakMinutes;     // 휴식 시간 적용
        _isBreakMode = true;
        _remainingSeconds = _breakMinutes * 60;
      });
      _startTimer(); // 휴식 자동 시작
    }
  }

  // ── 시간 변경 다이얼로그 ────────────────────────────────────────────────
  // 현재 모드(집중/휴식)의 시간만 변경. 최저값 미만은 다이얼로그가 거부.
  Future<void> _openDurationDialog() async {
    final isBreak = _isBreakMode;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _DurationPickerDialog(
        title: isBreak ? '휴식 시간 설정' : '집중 시간 설정',
        initialMinutes: isBreak ? _breakMinutes : _focusMinutes,
        presets: isBreak ? _kBreakPresets : _kFocusPresets,
        minMinutes: isBreak ? _kMinBreakMinutes : _kMinFocusMinutes,
        maxMinutes: isBreak ? _kMaxBreakMinutes : _kMaxFocusMinutes,
      ),
    );
    if (result == null) return;
    final minM = isBreak ? _kMinBreakMinutes : _kMinFocusMinutes;
    final maxM = isBreak ? _kMaxBreakMinutes : _kMaxFocusMinutes;
    final clamped = result.clamp(minM, maxM);
    setState(() {
      if (isBreak) {
        _breakMinutes = clamped;
      } else {
        _focusMinutes = clamped;
      }
      // 현재 모드의 남은 시간을 새 값으로 리셋
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
      _ticker?.cancel();
    });
  }

  // ── 과목 / 완료 / 재선택 ──────────────────────────────────────────────────
  bool get _currentTaskDone =>
      _selectedTask != null && (_doneMap[_selectedTask!.todoId] ?? false);

  void _toggleDone() {
    if (_selectedTask == null) return;
    setState(() {
      _doneMap[_selectedTask!.todoId] =
          !(_doneMap[_selectedTask!.todoId] ?? false);
    });
  }

  Future<void> _resetSelection() async {
    await _endSession();
    if (!mounted) return;
    _ticker?.cancel();
    if (_serviceReady) _service.reset();
    setState(() {
      _selectedTask = null;
      _isBreakMode = false;
      _remainingSeconds = _focusMinutes * 60;
      _isRunning = false;
    });
  }

  Future<void> _selectTask(CameraTask task) async {
    if (_selectedTask?.goalId != task.goalId) {
      await _endSession();
      await _startSession(task);
      if (_serviceReady) _service.reset(); // 새 task 선택 시 누적 점수 초기화
    }
    // task 선택만 함. 타이머 시작은 사용자가 ▶ 직접 눌러야 함.
    _ticker?.cancel();
    setState(() {
      _selectedTask = task;
      _isBreakMode = false;
      _remainingSeconds = _focusMinutes * 60;
      _isRunning = false;
    });
  }

  // ── 뒤로가기 (상단 < 버튼) ──────────────────────────────────────────────
  Future<void> _onBack() async {
    await _endSession();
    if (!mounted) return;
    Navigator.pop(context, {
      'selectedTask': _selectedTask?.text,
      'doneMap': {
        for (final t in widget.allTasks) t.text: _doneMap[t.todoId] ?? false,
      },
    });
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      // 다이얼로그 키보드 떠도 카메라 페이지 자체는 줄어들지 않도록
      // (키보드는 다이얼로그가 알아서 회피함)
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌측 줄이고 가운데 키워서 타이머가 화면 중앙에 가깝게
                    Expanded(flex: 28, child: _buildLeftTaskList()),
                    const SizedBox(width: 14),
                    Expanded(flex: 38, child: _buildCenter()),
                    const SizedBox(width: 14),
                    Expanded(flex: 22, child: _buildRightCamera()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 상단 바 ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final hasTask = _selectedTask != null;
    final chipText = hasTask ? _selectedTask!.displayLabel : '과목을 선택해주세요';
    final dotColor = hasTask ? _selectedTask!.color : const Color(0xFFCBCBCB);

    return Row(
      children: [
        // 뒤로가기
        GestureDetector(
          onTap: _onBack,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Icon(Icons.arrow_back_ios_new,
                size: 18, color: Color(0xFF555555)),
          ),
        ),
        const SizedBox(width: 4),

        // 선택된 과목 칩 (캡처처럼 가로로 늘어나는 형태)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 14, color: dotColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chipText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasTask
                          ? const Color(0xFF232323)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // 완료 / 미완료
        _SmallChipButton(
          text: _currentTaskDone ? '미완료' : '완료',
          enabled: hasTask,
          background: _kAccent,
          onTap: hasTask ? _toggleDone : null,
        ),
        const SizedBox(width: 6),

        // 재선택
        _SmallChipButton(
          text: '재선택',
          enabled: hasTask,
          background: Colors.white,
          textColor: const Color(0xFF555555),
          onTap: hasTask ? _resetSelection : null,
        ),
      ],
    );
  }

  // ─── 왼쪽 오늘 할 일 ────────────────────────────────────────────────────
  Widget _buildLeftTaskList() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘 할 일',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF232323),
                ),
              ),
              const Spacer(),
              Text(
                '${_doneMap.values.where((v) => v).length} / ${widget.allTasks.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF7E7E7E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...widget.allTasks.map(_buildTaskRow),
                  if (widget.allTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '오늘 할 일이 없습니다.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(CameraTask task) {
    final isSelected = _selectedTask?.todoId == task.todoId;
    final isDone = _doneMap[task.todoId] ?? false;

    return GestureDetector(
      onTap: () => _selectTask(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.circle,
              size: 11,
              color: isDone ? const Color(0xFFCBCBCB) : task.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.displayLabel,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  color: isDone
                      ? const Color(0xFFCBCBCB)
                      : const Color(0xFF555555),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: const Color(0xFFCBCBCB),
                ),
              ),
            ),
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.check_circle,
                    color: Color(0xFF8BCB75), size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // ─── 가운데: 타이머 (항상 보이게, 과목 미선택 시 컨트롤 비활성화) ──────
  Widget _buildCenter() {
    final hasTask = _selectedTask != null;
    final progress =
        _totalSeconds == 0 ? 0.0 : 1.0 - (_remainingSeconds / _totalSeconds);
    // 게이지/모드 라벨은 과목 색 무시하고 기존 빨강(_kAccentDark) 사용
    // (휴식은 초록, 미선택은 회색)
    final ringColor = hasTask
        ? (_isBreakMode ? const Color(0xFF6BAE6B) : _kAccentDark)
        : const Color(0xFFD0D0D0);
    final modeLabelColor = hasTask
        ? (_isBreakMode ? const Color(0xFF6BAE6B) : _kAccentDark)
        : const Color(0xFF999999);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 모드 라벨 (또는 안내)
        Text(
          hasTask ? (_isBreakMode ? '휴식' : '집중') : '과목을 선택해주세요',
          style: TextStyle(
            fontSize: hasTask ? 11 : 12,
            fontWeight: FontWeight.w800,
            color: modeLabelColor,
            letterSpacing: hasTask ? 1 : 0,
          ),
        ),
        const SizedBox(height: 10),

        // 원형 게이지 + 시간 (탭 시 시간 변경 — 과목 무관하게 가능)
        GestureDetector(
          onTap: _openDurationDialog,
          child: SizedBox(
            width: 170,
            height: 170,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: ringColor,
                trackColor: const Color(0xFFE8E8E8),
                strokeWidth: 7,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color:
                              hasTask ? Colors.black : const Color(0xFFAAAAAA),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '탭하여 시간 변경',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // 컨트롤 버튼들 (리셋 + 일시정지/재개) — 과목 없으면 비활성화
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: hasTask ? _resetTimer : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTask
                      ? const Color(0xFFEEEEEE)
                      : const Color(0xFFF5F5F5),
                ),
                child: Icon(
                  Icons.refresh,
                  size: 18,
                  color: hasTask
                      ? const Color(0xFF666666)
                      : const Color(0xFFCCCCCC),
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: hasTask ? _toggleRunning : null,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasTask ? Colors.black : const Color(0xFFCCCCCC),
                ),
                child: Icon(
                  _isRunning ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 오른쪽: 카메라 + 상태 배지 ──────────────────────────────────────────
  // 우측 영역에서 약간 아래에 배치 (Align bottomCenter 가까운 위치)
  Widget _buildRightCamera() {
    return Align(
      alignment: const Alignment(0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 카메라 프리뷰 — 휴식 모드면 카메라 OFF UI
          SizedBox(
            height: 85,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEDEDED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _isBreakMode
                    ? Container(
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.coffee,
                                  size: 22, color: Color(0xFF6BAE6B)),
                              SizedBox(height: 4),
                              Text(
                                '휴식 중',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6BAE6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (_camReady && _camCtrl != null)
                    ? LayoutBuilder(
                        builder: (ctx, constraints) {
                          // 카메라의 native aspect ratio 를 유지하면서
                          // 박스를 가득 채우기 (cover) — 비율 안 맞는 부분은 잘림
                          final ar = _camCtrl!.value.aspectRatio;
                          return SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: 100,
                                height: 100 / ar,
                                child: CameraPreview(_camCtrl!),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: _camError != null
                            ? Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  _camError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_outline,
                                size: 28, color: Color(0xFFC7C7C7)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── 실시간 집중도 결과 ──────────────────────────────────────────
          // 뽀모도로 진행 중(_isRunning && 집중 모드)일 때만 service 값 사용.
          // 시작 안 했거나 휴식 중이면 "측정 대기" 로 표시.
          ValueListenableBuilder<FocusResult>(
            valueListenable: _service.result,
            builder: (ctx, r, _) {
              final active = _isRunning && !_isBreakMode;
              final shownStatus = active ? r.status : FocusStatus.measuring;
              final shownLabel = active ? r.statusKr : '측정 대기';
              // 점수는 UI 에 표시 안 함 (세션 종료 후 평균만 노출 예정)

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 작은 배지
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _badgeBgColor(shownStatus),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 9, color: _statusColor(shownStatus)),
                          const SizedBox(width: 4),
                          Text(
                            shownLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusTextColor(shownStatus),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 큰 카드 제거됨 (작은 배지에 같은 정보 있음)
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _statusColor(FocusStatus s) {
    switch (s) {
      case FocusStatus.focused:
        return const Color(0xFF5AA85A); // 초록
      case FocusStatus.medium:
        return const Color(0xFFFF9800); // 주황
      case FocusStatus.distracted:
        return _kAccent; // 빨강
      case FocusStatus.measuring:
        return const Color(0xFF999999);
    }
  }

  Color _badgeBgColor(FocusStatus s) {
    switch (s) {
      case FocusStatus.focused:
        return const Color(0xFFE8F5E9);
      case FocusStatus.medium:
        return const Color(0xFFFFF3E0);
      case FocusStatus.distracted:
        return const Color(0xFFFFEEEE);
      case FocusStatus.measuring:
        return const Color(0xFFEEEEEE);
    }
  }

  Color _statusTextColor(FocusStatus s) {
    switch (s) {
      case FocusStatus.focused:
        return const Color(0xFF2E7D32);
      case FocusStatus.medium:
        return const Color(0xFFE65100);
      case FocusStatus.distracted:
        return const Color(0xFF8E5A56);
      case FocusStatus.measuring:
        return const Color(0xFF666666);
    }
  }

  // ── 유틸 ──────────────────────────────────────────────────────────────────
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 작은 둥근 칩 버튼 (완료 / 재선택)
// ─────────────────────────────────────────────────────────────────────────────
class _SmallChipButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final Color background;
  final Color? textColor;
  final VoidCallback? onTap;

  const _SmallChipButton({
    required this.text,
    required this.enabled,
    required this.background,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? (textColor ?? Colors.white) : const Color(0xFFCBCBCB);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? background : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 원형 진행 게이지 (시계방향으로 줄어드는 빨간 호)
// progress: 0.0 (가득) ~ 1.0 (다 사라짐)
// ─────────────────────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 배경 트랙
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 진행 호 (12시 시작, 시계방향)
    final remaining = (1.0 - progress).clamp(0.0, 1.0);
    final sweepAngle = -2 * math.pi * remaining; // 음수 = 시계방향에서 줄어드는 효과
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // 시작 각도 -π/2 = 12시 위치
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

// ─────────────────────────────────────────────────────────────────────────────
// 세션 종료 후 평가 다이얼로그
//   - 평균 점수 + 상태 라벨
//   - 다음 세션 추천 시간 안내
//   - 확인 버튼만 (수정은 휴식 후 타이머에서 가능)
// ─────────────────────────────────────────────────────────────────────────────
class _SessionEvalDialog extends StatelessWidget {
  final double avgScore;
  final int recommendedFocusMinutes;
  final int recommendedBreakMinutes;
  final int currentFocusMinutes;

  const _SessionEvalDialog({
    required this.avgScore,
    required this.recommendedFocusMinutes,
    required this.recommendedBreakMinutes,
    required this.currentFocusMinutes,
  });

  // 점수 → 라벨 + 색
  ({String label, Color color}) _statusInfo() {
    if (avgScore >= 70) {
      return (label: '집중', color: const Color(0xFF5AA85A));
    } else if (avgScore >= 40) {
      return (label: '보통', color: const Color(0xFFFF9800));
    } else {
      return (label: '부진', color: _kAccent);
    }
  }

  // 다음 세션 변화 설명 (▲ ▼ −)
  String _focusDelta() {
    final diff = recommendedFocusMinutes - currentFocusMinutes;
    if (diff > 0) return '+$diff분';
    if (diff < 0) return '$diff분';
    return '유지';
  }

  @override
  Widget build(BuildContext context) {
    final s = _statusInfo();
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // 가로 모드에서도 컴팩트 (280px 카드처럼 보이게)
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currentFocusMinutes분 집중 완료!',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),

              // 큰 점수 + 라벨
              Text(
                '${avgScore.toInt()}점',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: s.color,
                ),
              ),
              const SizedBox(height: 12),

              // 다음 세션 추천
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '다음 세션 추천',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _miniStat(
                          '집중',
                          '$recommendedFocusMinutes분',
                          sub: _focusDelta(),
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: const Color(0xFFE0E0E0),
                        ),
                        _miniStat('휴식', '$recommendedBreakMinutes분'),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '※ 휴식 후 타이머 탭하면 시간 변경 가능',
                      style: TextStyle(
                        fontSize: 7,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    '확인 (휴식 시작)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, {String? sub}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF888888),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF333333),
          ),
        ),
        if (sub != null && sub.isNotEmpty)
          Text(
            sub,
            style: TextStyle(
              fontSize: 8,
              color: sub.contains('+')
                  ? const Color(0xFF5AA85A)
                  : (sub.contains('-')
                      ? _kAccent
                      : const Color(0xFF888888)),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 세션 시간 설정 다이얼로그
//   - 칩으로 미리 정의된 시간 선택
//   - "직접 입력" 칩 선택 시 TextField 표시
//   - 취소 / 적용 버튼
// 결과: 선택된 분 (int) 또는 null (취소)
// ─────────────────────────────────────────────────────────────────────────────
class _DurationPickerDialog extends StatefulWidget {
  final String title;
  final int initialMinutes;
  final List<int> presets;
  final int minMinutes; // 이 값 미만은 거부
  final int maxMinutes;

  const _DurationPickerDialog({
    required this.title,
    required this.initialMinutes,
    required this.presets,
    required this.minMinutes,
    required this.maxMinutes,
  });

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _selected;
  bool _customMode = false;
  String? _errorText;
  late TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMinutes;
    _customMode = !widget.presets.contains(widget.initialMinutes);
    _customCtrl = TextEditingController(text: _selected.toString());
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _onApply() {
    if (_customMode) {
      final n = int.tryParse(_customCtrl.text.trim());
      if (n == null) {
        setState(() => _errorText = '숫자만 입력해주세요');
        return;
      }
      if (n < widget.minMinutes) {
        setState(() => _errorText = '${widget.minMinutes}분 이상으로 입력해주세요');
        return;
      }
      if (n > widget.maxMinutes) {
        setState(() => _errorText = '${widget.maxMinutes}분 이하로 입력해주세요');
        return;
      }
      Navigator.pop(context, n);
    } else {
      Navigator.pop(context, _selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    // 화면에서 키보드와 위/아래 여백 빼고 다이얼로그가 차지할 수 있는 최대 높이
    final maxDialogHeight = media.size.height - keyboardHeight - 40;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // 가로모드에서 다이얼로그 너비 적당히
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
      // 키보드를 회피해서 위로 올라가게 + 키보드 높이만큼 위로 밀림
      alignment: Alignment(0, -keyboardHeight / media.size.height),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '타이머 시간을 선택하거나 직접 입력하세요. (최저 ${widget.minMinutes}분)',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 14),

                // 시간 칩들
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...widget.presets.map(
                      (m) => _Chip(
                        label: '$m분',
                        selected: !_customMode && _selected == m,
                        onTap: () => setState(() {
                          _customMode = false;
                          _errorText = null;
                          _selected = m;
                        }),
                      ),
                    ),
                    _Chip(
                      label: '직접 입력',
                      selected: _customMode,
                      onTap: () => setState(() {
                        _customMode = true;
                        _errorText = null;
                      }),
                    ),
                  ],
                ),

                // 직접 입력 TextField
                if (_customMode) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      suffixText: '분',
                      hintText: '${widget.minMinutes} 이상',
                      isDense: true,
                      errorText: _errorText,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: _kAccent, width: 1.5),
                      ),
                    ),
                    onChanged: (v) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                      final n = int.tryParse(v);
                      if (n != null) _selected = n;
                    },
                    onSubmitted: (_) => _onApply(),
                  ),
                ],

                const SizedBox(height: 18),

                // 취소 / 적용
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _onApply,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          '적용',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 칩 (선택/비선택 상태)
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccent : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}
