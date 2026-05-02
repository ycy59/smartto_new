import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/study_session.dart';
import '../providers/study_session_provider.dart';

/// 카메라 화면에서 사용하는 할일 단위
class CameraTask {
  final String todoId;
  final String goalId;
  final String subjectId;
  final String text;

  const CameraTask({
    required this.todoId,
    required this.goalId,
    required this.subjectId,
    required this.text,
  });
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
  CameraTask? _selectedTask;
  late Map<String, bool> _doneMap; // todoId → done
  StudySession? _activeSession;

  // 카메라 프리뷰 (face detection / ML 없음, 화면에 비추기만 함)
  CameraController? _camCtrl;
  bool _camReady = false;
  String? _camError;

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialSelectedTask;
    _doneMap = {for (final t in widget.allTasks) t.todoId: false};
    if (_selectedTask != null) _startSession(_selectedTask!);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // 모바일(iOS/Android)에서만 카메라 시도. 웹/데스크탑은 placeholder 유지.
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _camError = '사용 가능한 카메라 없음');
        return;
      }
      // 셀카 우선, 없으면 첫 번째
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
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
    } catch (e) {
      if (mounted) setState(() => _camError = '카메라 오류: $e');
    }
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    super.dispose();
  }

  Future<void> _startSession(CameraTask task) async {
    if (task.goalId.isEmpty) return;
    _activeSession = await ref
        .read(studySessionProvider.notifier)
        .startSession(task.goalId);
  }

  Future<void> _endSession() async {
    if (_activeSession == null || _selectedTask == null) return;
    // TODO: MediaPipe 집중도 점수로 교체 (현재 65% 모의값 = Good 등급)
    const mockFocusScore = 0.65;
    await ref.read(studySessionProvider.notifier).endSession(
          session: _activeSession!,
          focusScore: mockFocusScore,
          subjectId: _selectedTask!.subjectId,
        );
    _activeSession = null;
  }

  bool get _currentTaskDone =>
      _selectedTask != null && (_doneMap[_selectedTask!.todoId] ?? false);

  void _toggleDone() {
    if (_selectedTask == null) return;
    setState(() {
      _doneMap[_selectedTask!.todoId] = !(_doneMap[_selectedTask!.todoId] ?? false);
    });
  }

  void _resetSelection() {
    setState(() => _selectedTask = null);
  }

  void _selectTask(CameraTask task) {
    if (_selectedTask?.goalId != task.goalId) {
      _endSession().then((_) => _startSession(task));
    }
    setState(() => _selectedTask = task);
  }

  @override
  Widget build(BuildContext context) {
    final chipText =
        (_selectedTask == null || _selectedTask!.text.trim().isEmpty)
            ? '과목을 선택하세요'
            : _selectedTask!.text;

    final bool canToggle = _selectedTask != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              // ── 상단 바 ──────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Camera-go',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                  const Spacer(),

                  // 선택된 과목 칩
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F1F1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: canToggle
                              ? const Color(0xFFD97068)
                              : const Color(0xFFCBCBCB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          chipText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: canToggle
                                ? const Color(0xFF4A4A4A)
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  GestureDetector(
                    onTap: canToggle ? _toggleDone : null,
                    child: Text(
                      _currentTaskDone ? '미완료' : '완료',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !canToggle
                            ? const Color(0xFFCBCBCB)
                            : _currentTaskDone
                                ? const Color(0xFF9A9A9A)
                                : const Color(0xFF232323),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  GestureDetector(
                    onTap: _resetSelection,
                    child: const Text(
                      '재선택',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A7A7A),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── 메인 영역 ─────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 왼쪽: 오늘 할 일 목록
                    Expanded(
                      flex: 34,
                      child: Container(
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
                            ...widget.allTasks.map((task) => _buildTask(task)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // 가운데: 타이머 + 일시정지 버튼
                    Expanded(
                      flex: 32,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFB34C3D),
                                width: 5,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '20:38',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          GestureDetector(
                            onTap: () async {
                              await _endSession();
                              if (!mounted) return;
                              Navigator.pop(context, {
                                'selectedTask': _selectedTask?.text,
                                'doneMap': {
                                  for (final t in widget.allTasks)
                                    t.text: _doneMap[t.todoId] ?? false,
                                },
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: const Icon(
                                Icons.pause,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // 오른쪽: 카메라 영역
                    Expanded(
                      flex: 22,
                      child: Column(
                        children: [
                          const Spacer(),
                          Container(
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDEDED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: (_camReady && _camCtrl != null)
                                  ? CameraPreview(_camCtrl!)
                                  : Center(
                                      child: _camError != null
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.all(4),
                                              child: Text(
                                                _camError!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF999999),
                                                ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_outline,
                                              size: 34,
                                              color: Color(0xFFC7C7C7),
                                            ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTask(CameraTask task) {
    final bool isSelected = _selectedTask?.todoId == task.todoId;
    final bool isDone = _doneMap[task.todoId] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _selectTask(task),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: isDone
                  ? const Color(0xFFCBCBCB)
                  : const Color(0xFFD97068),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.text,
                style: TextStyle(
                  fontSize: 11,
                  color: isDone
                      ? const Color(0xFFCBCBCB)
                      : const Color(0xFF555555),
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: const Color(0xFFCBCBCB),
                ),
              ),
            ),
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xFF8BCB75),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
