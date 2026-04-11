import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/concentration_camera.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry: modal helper called from TomatoNavItem
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showPomodoroStartModal(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _PomodoroStartDialog(),
  );
  if (result == true && context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PomodoroTimerScreen()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PomodoroStartDialog extends StatelessWidget {
  const _PomodoroStartDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/tomato_glasses.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '시작하시겠습니까?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '집중 모드를 시작합니다.\n카메라로 집중도를 측정합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF888888),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF888888),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('취소',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD8645C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('시작',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task model
// ─────────────────────────────────────────────────────────────────────────────

class _Task {
  final String subject;   // 과목명 (e.g. "알고리즘")
  final String detail;    // 세부 내용 (e.g. "Chapter1 복습")
  bool done;
  final Color color;

  _Task({
    required this.subject,
    required this.detail,
    required this.done,
    required this.color,
  });

  String get fullLabel => '$subject - $detail';
}

// ─────────────────────────────────────────────────────────────────────────────
// Pomodoro Timer Screen
// ─────────────────────────────────────────────────────────────────────────────

class PomodoroTimerScreen extends StatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {
  // ── 세션 시간 (기본 25분, 사용자 편집 가능) ─────────────────────────────
  int _sessionMinutes = 25;
  late int _totalSeconds;
  late int _remaining;

  bool _running = false;
  Timer? _timer;

  // ── 할 일 목록 ────────────────────────────────────────────────────────────
  final List<_Task> _tasks = [
    _Task(subject: '알고리즘', detail: 'Chapter1 복습',     done: false, color: Color(0xFFD8645C)),
    _Task(subject: '알고리즘', detail: '버블정렬 구현',      done: false, color: Color(0xFFD8645C)),
    _Task(subject: '운영체제', detail: '3장 읽기',           done: false, color: Color(0xFF9B6BC8)),
    _Task(subject: '운영체제', detail: 'Chapter1 문제',      done: true,  color: Color(0xFFE8A838)),
    _Task(subject: '인터넷 프로그래밍', detail: '1장과제',   done: false, color: Color(0xFF5A9FD4)),
  ];

  int? _selectedTaskIndex;

  // ── 집중도 결과 상태 ────────────────────────────────────────────────────────
  FocusResult _focusResult = const FocusResult(status: FocusStatus.measuring, score: 0);

  @override
  void initState() {
    super.initState();
    _totalSeconds = _sessionMinutes * 60;
    _remaining    = _totalSeconds;
    // 가로 모드 고정
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 세로 모드 복원
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  // ── 타이머 제어 ───────────────────────────────────────────────────────────

  void _toggleTimer() {
    // 할 일 미선택 시 경고
    if (!_running && _selectedTaskIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                '먼저 오늘 할 일에서 항목을 선택해주세요!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD8645C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_running) {
        _timer?.cancel();
        _running = false;
      } else {
        _running = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_remaining > 0) {
            setState(() => _remaining--);
          } else {
            _timer?.cancel();
            setState(() => _running = false);
            _onTimerComplete();
          }
        });
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _totalSeconds = _sessionMinutes * 60;
      _remaining    = _totalSeconds;
      _running      = false;
    });
  }

  void _onTimerComplete() {
    final score = _focusResult.score.toStringAsFixed(0);
    final status = _focusResult.statusKr;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('세션 완료! 🎉', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '포모도로 세션이 끝났습니다.\n\n'
          '최종 집중도: $score점 ($status)\n\n'
          '잠시 휴식을 취하세요.',
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); _resetTimer(); },
            child: const Text('확인', style: TextStyle(color: Color(0xFFD8645C))),
          ),
        ],
      ),
    );
  }

  // ── 세션 시간 편집 ────────────────────────────────────────────────────────

  void _editSessionTime() async {
    if (_running) return; // 실행 중엔 변경 불가
    final presets = [5, 10, 15, 20, 25, 30, 45, 60];
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _SessionTimePicker(
        currentMinutes: _sessionMinutes,
        presets: presets,
      ),
    );
    if (chosen != null) {
      setState(() {
        _sessionMinutes = chosen;
        _totalSeconds   = chosen * 60;
        _remaining      = _totalSeconds;
      });
    }
  }

  // ── 할 일 선택 ────────────────────────────────────────────────────────────

  void _selectTask(int index) {
    setState(() {
      // 이미 선택된 항목 다시 누르면 해제
      _selectedTaskIndex = (_selectedTaskIndex == index) ? null : index;
    });
  }

  // ── 완료 / 미완료 토글 ────────────────────────────────────────────────────

  void _toggleTaskDone() {
    if (_selectedTaskIndex == null) return;
    setState(() {
      _tasks[_selectedTaskIndex!].done = !_tasks[_selectedTaskIndex!].done;
    });
  }

  // ── 표시용 문자열 ────────────────────────────────────────────────────────

  String get _timeString {
    final m = _remaining ~/ 60;
    final s = _remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => 1.0 - _remaining / _totalSeconds;

  String get _topBarLabel {
    if (_selectedTaskIndex != null) {
      return _tasks[_selectedTaskIndex!].fullLabel;
    }
    return '과목을 선택하세요';
  }

  Color? get _selectedTaskColor {
    if (_selectedTaskIndex != null) return _tasks[_selectedTaskIndex!].color;
    return null;
  }

  bool get _selectedTaskDone {
    if (_selectedTaskIndex != null) return _tasks[_selectedTaskIndex!].done;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 바 ─────────────────────────────────────────────────────
            _TopBar(
              label: _topBarLabel,
              selectedColor: _selectedTaskColor,
              selectedTaskDone: _selectedTaskDone,
              hasSubject: _selectedTaskIndex != null,
              onToggleDone: _toggleTaskDone,
              onReselect: () => setState(() => _selectedTaskIndex = null),
            ),
            // ── 메인 콘텐츠 (가로 레이아웃) ─────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 왼쪽: 할 일 목록
                    SizedBox(
                      width: 210,
                      child: _TaskListPanel(
                        tasks: _tasks,
                        selectedIndex: _selectedTaskIndex,
                        onSelect: _selectTask,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 오른쪽: 타이머 + 버튼 + 카메라
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 원형 타이머 (탭으로 시간 편집)
                          GestureDetector(
                            onTap: _editSessionTime,
                            child: _CircularTimer(
                              progress: _progress,
                              timeString: _timeString,
                              sessionMinutes: _sessionMinutes,
                              isRunning: _running,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 버튼 행
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _IconCircleButton(
                                icon: Icons.refresh,
                                size: 36,
                                bgColor: const Color(0xFFEAEAEA),
                                iconColor: const Color(0xFF888888),
                                onTap: _resetTimer,
                              ),
                              const SizedBox(width: 16),
                              _IconCircleButton(
                                icon: _running ? Icons.pause : Icons.play_arrow,
                                size: 52,
                                bgColor: Colors.black,
                                iconColor: Colors.white,
                                onTap: _toggleTimer,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 오른쪽 끝: 카메라 + 집중도
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConcentrationCamera(
                          isActive: _running,
                          onFocusUpdate: (result) {
                            setState(() => _focusResult = result);
                          },
                        ),
                        const SizedBox(height: 8),
                        // 집중도 점수 카드
                        if (_running) _FocusScoreCard(result: _focusResult),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String label;
  final Color? selectedColor;   // 선택된 task의 색상 (없으면 null)
  final bool hasSubject;
  final bool selectedTaskDone;  // 선택된 task가 완료 상태인지
  final VoidCallback onToggleDone;
  final VoidCallback onReselect;

  const _TopBar({
    required this.label,
    required this.selectedColor,
    required this.hasSubject,
    required this.selectedTaskDone,
    required this.onToggleDone,
    required this.onReselect,
  });

  @override
  Widget build(BuildContext context) {
    // 완료된 task 선택 → "미완료" 버튼, 미완료 task 선택 → "완료" 버튼
    final actionLabel = (!hasSubject)
        ? '완료'
        : (selectedTaskDone ? '미완료' : '완료');
    final actionEnabled = hasSubject;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 12),

          // ── 과목 선택 pill (스크린샷 스타일) ─────────────────────────────
          Expanded(
            child: _SubjectPill(
              label: label,
              dotColor: selectedColor,
              hasSubject: hasSubject,
            ),
          ),
          const SizedBox(width: 8),

          // 완료 / 미완료 버튼
          _TextActionButton(
            label: actionLabel,
            onTap: actionEnabled ? onToggleDone : null,
            highlight: hasSubject && !selectedTaskDone, // 미완료 task 선택 시 강조
          ),
          const SizedBox(width: 6),

          // 재선택 버튼
          _TextActionButton(
            label: '재선택',
            onTap: hasSubject ? onReselect : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Pill — 스크린샷과 같은 회색 pill + 왼쪽 원형 인디케이터
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectPill extends StatelessWidget {
  final String label;
  final Color? dotColor;   // 선택된 task의 색상 (null이면 빈 원)
  final bool hasSubject;

  const _SubjectPill({
    required this.label,
    required this.dotColor,
    required this.hasSubject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 왼쪽 원형 인디케이터
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor ?? Colors.transparent,
              border: Border.all(
                color: dotColor ?? const Color(0xFFBBBBBB),
                width: dotColor != null ? 0 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 과목/할일 텍스트
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasSubject ? Colors.black : const Color(0xFF888888),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool highlight;

  const _TextActionButton({
    required this.label,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFD8645C)
              : (isDisabled ? const Color(0xFFF2F2F2) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? const Color(0xFFD8645C)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: highlight
                ? Colors.white
                : (isDisabled
                    ? const Color(0xFFBBBBBB)
                    : const Color(0xFF666666)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task List Panel (왼쪽) — 배경색 #E5F2FB
// ─────────────────────────────────────────────────────────────────────────────

class _TaskListPanel extends StatelessWidget {
  final List<_Task> tasks;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  const _TaskListPanel({
    required this.tasks,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final total     = tasks.length;
    final doneCount = tasks.where((t) => t.done).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5F2FB),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘 할 일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$doneCount/$total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A8FCB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final task      = tasks[i];
                final isSelected = selectedIndex == i;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: task.color, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: task.done
                                ? const Color(0xFFCCCCCC)
                                : task.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.fullLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: task.done
                                  ? const Color(0xFFBBBBBB)
                                  : (isSelected
                                      ? Colors.black
                                      : const Color(0xFF444444)),
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        if (task.done)
                          const Icon(Icons.check_circle,
                              size: 14, color: Color(0xFFCCCCCC)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular Timer
// ─────────────────────────────────────────────────────────────────────────────

class _CircularTimer extends StatelessWidget {
  final double progress;
  final String timeString;
  final int sessionMinutes;
  final bool isRunning;

  const _CircularTimer({
    required this.progress,
    required this.timeString,
    required this.sessionMinutes,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _TimerPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                timeString,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
              if (!isRunning)
                const Text(
                  '탭하여 시간 변경',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;

  _TimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // 배경 트랙
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFEEEEEE)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // 진행 아크
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = const Color(0xFFD8645C)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Time Picker Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTimePicker extends StatefulWidget {
  final int currentMinutes;
  final List<int> presets;

  const _SessionTimePicker({
    required this.currentMinutes,
    required this.presets,
  });

  @override
  State<_SessionTimePicker> createState() => _SessionTimePickerState();
}

class _SessionTimePickerState extends State<_SessionTimePicker> {
  late int _selected;
  late TextEditingController _customController;
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMinutes;
    _customController = TextEditingController(
      text: widget.presets.contains(widget.currentMinutes)
          ? ''
          : widget.currentMinutes.toString(),
    );
    _showCustom = !widget.presets.contains(widget.currentMinutes);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '세션 시간 설정',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '타이머 시간을 선택하거나 직접 입력하세요.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 16),
            // 프리셋 그리드
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.presets.map((min) {
                final isSelected = !_showCustom && _selected == min;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selected    = min;
                    _showCustom  = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD8645C)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$min분',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF444444),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // 직접 입력
            GestureDetector(
              onTap: () => setState(() => _showCustom = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _showCustom
                      ? const Color(0xFFF8EAEA)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: _showCustom
                      ? Border.all(color: const Color(0xFFD8645C), width: 1.5)
                      : null,
                ),
                child: _showCustom
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: '분 단위 입력',
                                hintStyle: TextStyle(color: Color(0xFFAAAAAA)),
                              ),
                              onChanged: (v) {
                                final parsed = int.tryParse(v);
                                if (parsed != null && parsed > 0) {
                                  setState(() => _selected = parsed);
                                }
                              },
                            ),
                          ),
                          const Text('분',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD8645C))),
                        ],
                      )
                    : const Text(
                        '직접 입력',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF888888)),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF888888),
                      side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('취소',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      int result = _selected;
                      if (_showCustom) {
                        result = int.tryParse(_customController.text) ?? _selected;
                      }
                      if (result <= 0) result = 1;
                      if (result > 120) result = 120;
                      Navigator.of(context).pop(result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD8645C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('적용',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon Circle Button
// ─────────────────────────────────────────────────────────────────────────────

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _IconCircleButton({
    required this.icon,
    required this.size,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.48),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera Placeholder
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// 집중도 점수 카드 (타이머 실행 중 카메라 아래 표시)
// ─────────────────────────────────────────────────────────────────────────────

class _FocusScoreCard extends StatelessWidget {
  final FocusResult result;

  const _FocusScoreCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: result.statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                result.statusKr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: result.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.score.toStringAsFixed(0)}점',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_outline, size: 30, color: Color(0xFF888888)),
          SizedBox(height: 4),
          Text(
            'Camera',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
