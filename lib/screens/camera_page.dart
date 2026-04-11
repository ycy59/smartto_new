import 'package:flutter/material.dart';

class CameraPage extends StatefulWidget {
  final String? initialSelectedTask;
  final List<String> allTasks;

  const CameraPage({
    super.key,
    required this.initialSelectedTask,
    required this.allTasks,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late String? _selectedTask;
  late Map<String, bool> _doneMap;

  @override
  void initState() {
    super.initState();
    _selectedTask = widget.initialSelectedTask;
    // 각 할 일의 완료 상태를 개별 관리
    _doneMap = {for (final t in widget.allTasks) t: false};
  }

  // 현재 선택된 할 일의 완료 여부
  bool get _currentTaskDone =>
      _selectedTask != null && (_doneMap[_selectedTask] ?? false);

  // 완료/미완료 토글
  void _toggleDone() {
    if (_selectedTask == null) return;
    setState(() {
      _doneMap[_selectedTask!] = !(_doneMap[_selectedTask!] ?? false);
    });
  }

  // 재선택: 선택 초기화
  void _resetSelection() {
    setState(() {
      _selectedTask = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chipText = (_selectedTask == null || _selectedTask!.trim().isEmpty)
        ? '과목을 선택하세요'
        : _selectedTask!;

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

                  // 완료 / 미완료 버튼 (과목 선택 전엔 비활성)
                  GestureDetector(
                    onTap: canToggle ? _toggleDone : null,
                    child: Text(
                      _currentTaskDone ? '미완료' : '완료',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !canToggle
                            ? const Color(0xFFCBCBCB)   // 비활성
                            : _currentTaskDone
                                ? const Color(0xFF9A9A9A) // 미완료
                                : const Color(0xFF232323), // 완료
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 재선택 버튼
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
                            ...widget.allTasks.map((task) =>
                                _buildTask(task)),
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
                            onTap: () {
                              Navigator.pop(context, {
                                'selectedTask': _selectedTask,
                                'isCompleted': _currentTaskDone,
                                'doneMap': _doneMap,
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
                            child: const Center(
                              child: Icon(
                                Icons.person_outline,
                                size: 34,
                                color: Color(0xFFC7C7C7),
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

  Widget _buildTask(String task) {
    final bool isSelected = _selectedTask == task;
    final bool isDone = _doneMap[task] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTask = task;
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 색상 점
            Icon(
              Icons.circle,
              size: 8,
              color: isDone
                  ? const Color(0xFFCBCBCB)
                  : const Color(0xFFD97068),
            ),
            const SizedBox(width: 8),

            // 할 일 텍스트
            Expanded(
              child: Text(
                task,
                style: TextStyle(
                  fontSize: 11,
                  color: isDone
                      ? const Color(0xFFCBCBCB)   // 완료: #CBCBCB
                      : const Color(0xFF555555),   // 미완료: 기본
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  decoration: isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: const Color(0xFFCBCBCB),
                ),
              ),
            ),

            // 완료 체크 아이콘
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