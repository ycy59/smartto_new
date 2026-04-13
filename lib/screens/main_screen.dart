import 'package:flutter/material.dart';
import 'subject_page.dart';
import 'calendar_page.dart';
import 'my_page.dart';
import 'camera_page.dart';
import 'report_page.dart';

List<String> globalTodayTasks = [];

class MainScreen extends StatefulWidget {
  final String nickname;
  final String? profileImagePath;
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const MainScreen({
    super.key,
    required this.nickname,
    this.profileImagePath,
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_TodayPlanCardState> _todayPlanKey =
      GlobalKey<_TodayPlanCardState>();

  late String _nickname;
  String? _profileImagePath;
  String? _selectedTaskTitle;

  @override
  void initState() {
  super.initState();
  _nickname = widget.nickname;
  _profileImagePath = widget.profileImagePath;
}

  void _handleTaskSelected(String taskTitle) {
    setState(() {
      _selectedTaskTitle = taskTitle;
  });
}

void _openMyPage() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MyPage(
        initialNickname: _nickname,
        initialProfileImagePath: _profileImagePath,
        currentIndex: widget.currentIndex,
        onTapNav: widget.onTapNav,
        onProfileUpdated: ({
          required String nickname,
          String? profileImagePath,
        }) {
          setState(() {
            _nickname = nickname;
            _profileImagePath = profileImagePath;
          });
        },
      ),
    ),
  );
}

  Future<void> _showStartDialog() async {
    final allTasks = _todayPlanKey.currentState?.getAllTodoTitles() ?? [];
    globalTodayTasks = allTasks;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 38),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/tomato_glasses.png',
                  width: 66,
                  height: 66,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  '시작하시겠습니까?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF232323),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '집중 모드를 시작합니다.\n카메라로 집중도를 측정합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF8F8F8F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E5E5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: const Color(0xFFF8F8F8),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              color: Color(0xFF9A9A9A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97068),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '시작',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

   if (result != true) return;

    final pageResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(
          initialSelectedTask: _selectedTaskTitle,
          allTasks: allTasks,
        ),
      ),
    );

    if (pageResult != null) {
      final selectedTask = pageResult['selectedTask'] as String?;
      final doneMap = pageResult['doneMap'] as Map<String, bool>? ?? {};

      if (selectedTask != null && selectedTask.isNotEmpty) {
        setState(() {
          _selectedTaskTitle = selectedTask;
        });
      }

      doneMap.forEach((task, isDone) {
        _todayPlanKey.currentState?.markTaskDoneByText(task, isDone);
      });
    }
  }  // ← _showStartDialog 닫는 괄호

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -100) {
            _openMyPage();
          }
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            GreetingCard(nickname: _nickname),
                            const SizedBox(height: 16),
                            const WeeklyStatsCard(),
                            const SizedBox(height: 16),
                            TodayPlanCard(
                              key: _todayPlanKey,
                              selectedTaskTitle: _selectedTaskTitle,
                              onTaskSelected: _handleTaskSelected,
                            ),
                            const SizedBox(height: 10),
                            const PageIndicatorDots(),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                    BottomNavBar(
                      currentIndex: widget.currentIndex,
                      onTapNav: widget.onTapNav,
                      onTapTomato: _showStartDialog,
                      nickname: _nickname,
                      profileImagePath: _profileImagePath,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_alt, size: 16, color: Colors.black),
              SizedBox(width: 4),
              Icon(Icons.wifi, size: 16, color: Colors.black),
              SizedBox(width: 4),
              Icon(Icons.battery_full, size: 18, color: Colors.black),
            ],
          ),
        ],
      ),
    );
  }
}

class GreetingCard extends StatelessWidget {
  final String nickname;

  const GreetingCard({
    super.key,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = nickname.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName.isEmpty ? '안녕하세요!' : '안녕하세요 ${displayName}님!',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF444444),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '오늘도 스마트하게!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: InfoCard(
                  title: '학습 시간',
                  value: '1H 25M',
                  changeText: '▲ 12.5%',
                  changeColor: Color(0xFFC96B63),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  title: '목표 시간',
                  value: '3H 00M',
                  changeText: '▼ 3.1%',
                  changeColor: Color(0xFF6D88D8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;
  final Color changeColor;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.changeText,
    required this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EAEA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF5E5E5E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 10,
                  color: changeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyStatsCard extends StatelessWidget {
  const WeeklyStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Text(
                '이번주 통계',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              Text(
                '상세 보기',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFE27E76),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              StatItem(
                circleColor: Color(0xFFF1D1CC),
                iconColor: Color(0xFFC96B63),
                icon: Icons.timer,
                value: '0분',
                label: '총 집중',
              ),
              StatItem(
                circleColor: Color(0xFFDCE9CE),
                iconColor: Color(0xFF789F57),
                icon: Icons.check_circle,
                value: '0개',
                label: '완료 세션',
              ),
              StatItem(
                circleColor: Color(0xFFF4DEAE),
                iconColor: Color(0xFFD9A247),
                icon: Icons.group_work_rounded,
                value: '-%',
                label: '평균 집중도',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final Color circleColor;
  final Color iconColor;
  final IconData icon;
  final String value;
  final String label;

  const StatItem({
    super.key,
    required this.circleColor,
    required this.iconColor,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayPlanCard extends StatefulWidget {
  final String? selectedTaskTitle;
  final ValueChanged<String> onTaskSelected;

  TodayPlanCard({
    super.key,
    required this.selectedTaskTitle,
    required this.onTaskSelected,
  });

  @override
  State<TodayPlanCard> createState() => _TodayPlanCardState();
}

class _TodayPlanCardState extends State<TodayPlanCard> {
  bool _isEditing = false;
  int? _paletteOpenIndex;

  final List<Color> _subjectColors = const [
    Color(0xFFE06B63),
    Color(0xFF79B13D),
    Color(0xFF7B89FF),
    Color(0xFF9F88FF),
    Color(0xFFF0C06F),
    Color(0xFFF08AA1),
  ];

  final List<MainPlanSubject> _subjects = [
    MainPlanSubject(
      title: '데이터베이스',
      color: const Color(0xFFE06B63),
      dday: 17,
      todos: [
        MainPlanTodo(text: 'SQLite 실습', done: false),
        MainPlanTodo(text: 'SQL 기본 쿼리 복습', done: true),
      ],
    ),
    MainPlanSubject(
      title: '인터넷 프로그래밍',
      color: const Color(0xFF79B13D),
      dday: 0,
      todos: [
        MainPlanTodo(text: 'map / filter / reduce 연습 문제', done: true),
      ],
    ),
  ];

  List<String> getAllTodoTitles() {
    final List<String> result = [];

    for (final subject in _subjects) {
      for (final todo in subject.todos) {
        final text = todo.text.trim();
        if (text.isNotEmpty) {
          result.add(text);
        }
      }
    }

    return result;
  }

  void markTaskDoneByText(String taskText, bool done) {
    setState(() {
      for (final subject in _subjects) {
        for (final todo in subject.todos) {
          if (todo.text.trim() == taskText.trim()) {
            todo.done = done;
          }
        }
      }
    });
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _paletteOpenIndex = null;
      }
    });
  }

  void _addSubject() {
    setState(() {
      _subjects.add(
        MainPlanSubject(
          title: '새 과목',
          color: _subjectColors.first,
          dday: 0,
          todos: [
            MainPlanTodo(text: '', done: false),
          ],
        ),
      );
    });
  }

  Future<void> _confirmDeleteSubject(int subjectIndex) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('과목 삭제'),
          content: const Text('정말 이 과목을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _subjects.removeAt(subjectIndex);
        if (_paletteOpenIndex == subjectIndex) {
          _paletteOpenIndex = null;
        }
      });
    }
  }

  Future<void> _confirmDeleteTodo(int subjectIndex, int todoIndex) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('계획 삭제'),
          content: const Text('정말 이 계획을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _subjects[subjectIndex].todos.removeAt(todoIndex);
        if (_subjects[subjectIndex].todos.isEmpty) {
          _subjects[subjectIndex].todos.add(
            MainPlanTodo(text: '', done: false),
          );
        }
      });
    }
  }

  void _addNextTodo(int subjectIndex, int todoIndex) {
    setState(() {
      _subjects[subjectIndex].todos.insert(
        todoIndex + 1,
        MainPlanTodo(text: '', done: false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 계획',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleEdit,
                child: Text(
                  _isEditing ? '완료' : '편집',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEE7E76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: _addSubject,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('과목 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEE7E76),
                    side: const BorderSide(color: Color(0xFFF299B2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ...List.generate(_subjects.length, (subjectIndex) {
            final subject = _subjects[subjectIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _EditableSubjectBlock(
                subject: subject,
                isEditing: _isEditing,
                showPalette: _paletteOpenIndex == subjectIndex,
                selectedTaskTitle: widget.selectedTaskTitle,
                onTaskSelected: widget.onTaskSelected,
                onTogglePalette: () {
                  setState(() {
                    _paletteOpenIndex =
                        _paletteOpenIndex == subjectIndex ? null : subjectIndex;
                  });
                },
                subjectColors: _subjectColors,
                onDeleteSubject: () => _confirmDeleteSubject(subjectIndex),
                onPickColor: (color) {
                  setState(() {
                    subject.color = color;
                  });
                },
                onChangedTitle: (value) {
                  subject.title = value;
                },
                onChangedDday: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    subject.dday = parsed;
                  }
                },
                onToggleTodo: (todoIndex) {
                  setState(() {
                    subject.todos[todoIndex].done = !subject.todos[todoIndex].done;
                  });
                },
                onRemoveTodo: (todoIndex) =>
                    _confirmDeleteTodo(subjectIndex, todoIndex),
                onSubmittedTodo: (todoIndex) =>
                    _addNextTodo(subjectIndex, todoIndex),
                onChangedTodo: (todoIndex, value) {
                  subject.todos[todoIndex].text = value;
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class MainPlanSubject {
  String title;
  Color color;
  int dday;
  List<MainPlanTodo> todos;

  MainPlanSubject({
    required this.title,
    required this.color,
    required this.dday,
    required this.todos,
  });
}

class MainPlanTodo {
  String text;
  bool done;

  MainPlanTodo({
    required this.text,
    required this.done,
  });
}

class _EditableSubjectBlock extends StatelessWidget {
  final MainPlanSubject subject;
  final bool isEditing;
  final bool showPalette;
  final String? selectedTaskTitle;
  final ValueChanged<String> onTaskSelected;
  final VoidCallback onTogglePalette;
  final List<Color> subjectColors;
  final VoidCallback onDeleteSubject;
  final ValueChanged<Color> onPickColor;
  final ValueChanged<String> onChangedTitle;
  final ValueChanged<String> onChangedDday;
  final ValueChanged<int> onToggleTodo;
  final ValueChanged<int> onRemoveTodo;
  final ValueChanged<int> onSubmittedTodo;
  final void Function(int, String) onChangedTodo;

  const _EditableSubjectBlock({
    super.key,
    required this.subject,
    required this.isEditing,
    required this.showPalette,
    required this.selectedTaskTitle,
    required this.onTaskSelected,
    required this.onTogglePalette,
    required this.subjectColors,
    required this.onDeleteSubject,
    required this.onPickColor,
    required this.onChangedTitle,
    required this.onChangedDday,
    required this.onToggleTodo,
    required this.onRemoveTodo,
    required this.onSubmittedTodo,
    required this.onChangedTodo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: subject.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isEditing
                  ? TextFormField(
                      initialValue: subject.title,
                      onChanged: onChangedTitle,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Text(
                      subject.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (isEditing) ...[
              GestureDetector(
                onTap: onTogglePalette,
                child: const Icon(
                  Icons.palette_outlined,
                  size: 17,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDeleteSubject,
                child: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFCC6B6B),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.add_circle_outline,
                size: 17,
                color: Color(0xFFBDBDBD),
              ),
            ],
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF2E1E2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isEditing
                  ? SizedBox(
                      width: 42,
                      child: TextFormField(
                        initialValue: '${subject.dday}',
                        onChanged: onChangedDday,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8F7177),
                        ),
                      ),
                    )
                  : Text(
                      'D - ${subject.dday}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8F7177),
                      ),
                    ),
            ),
          ],
        ),
        if (showPalette) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: subjectColors.map((color) {
              final selected = subject.color == color;

              return GestureDetector(
                onTap: () => onPickColor(color),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        ...List.generate(subject.todos.length, (todoIndex) {
          final todo = subject.todos[todoIndex];
          final controller = TextEditingController(text: todo.text);
          final bool isSelected = selectedTaskTitle == todo.text.trim();

          return Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 8),
            child: GestureDetector(
              onTap: isEditing
                  ? null
                  : () {
                      final text = todo.text.trim();
                      if (text.isNotEmpty) {
                        onTaskSelected(text);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFF1EF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: const Color(0xFFF1B0A9))
                      : null,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onToggleTodo(todoIndex),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: todo.done
                              ? subject.color
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: todo.done
                            ? const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: isEditing
                          ? TextField(
                              controller: controller,
                              onChanged: (value) => onChangedTodo(todoIndex, value),
                              onSubmitted: (_) => onSubmittedTodo(todoIndex),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFD9D9D9)),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFD9D9D9)),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFBDBDBD)),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                color: todo.done
                                    ? const Color(0xFFCBCBCB)
                                    : const Color(0xFF8A8A8A),
                              ),
                            )
                          : Text(
                              todo.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: todo.done
                                    ? const Color(0xFFCBCBCB)
                                    : const Color(0xFF8A8A8A),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                    ),
                    if (todo.done)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 17,
                          color: Color(0xFF8BCB75),
                        ),
                      ),
                    if (isEditing)
                      GestureDetector(
                        onTap: () => onRemoveTodo(todoIndex),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFFB3B3B3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class PageIndicatorDots extends StatelessWidget {
  const PageIndicatorDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _SmallDot(active: true),
          SizedBox(width: 4),
          _SmallDot(active: false),
        ],
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  final bool active;

  const _SmallDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 7 : 5,
      height: active ? 7 : 5,
      decoration: BoxDecoration(
        color: active ? Colors.black : const Color(0xFFBDBDBD),
        shape: BoxShape.circle,
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final VoidCallback onTapTomato;
  final String nickname;
  final String? profileImagePath;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
    required this.onTapTomato,
    required this.nickname,
    this.profileImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F0),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE9E9E9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          NavItem(
            icon: Icons.home,
            label: 'Home',
            active: currentIndex == 0,
            onTap: () => onTapNav(0),
          ),
          NavItem(
            icon: Icons.calendar_month,
            label: 'Calendar',
            active: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarPageShell(
                    currentIndex: 1,
                    onTapNav: onTapNav,
                    nickname: nickname,
                    profileImagePath: profileImagePath,
                  ),
                ),
              );
            },
          ),
          TomatoNavItem(onTap: onTapTomato),
          NavItem(
            icon: Icons.bar_chart,
            label: 'Report',
            active: false,
            onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportPageShell(
                      currentIndex: 3,
                      onTapNav: onTapNav,
                      nickname: nickname,
                      profileImagePath: profileImagePath,
                    ),
                  ),
                );
            },
          ),
          NavItem(
            icon: Icons.book,
            label: 'Subject',
            active: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubjectPageShell(
                    currentIndex: 2,
                    onTapNav: onTapNav,
                    nickname: nickname,
                    profileImagePath: profileImagePath,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? const Color(0xFFE08C84) : const Color(0xFFC8C8C8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class TomatoNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const TomatoNavItem({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            padding: const EdgeInsets.all(1),
            child: ClipOval(
              child: Image.asset(
                'assets/images/tomato_glasses.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class TodoItem {
  String title;
  bool isDone;

  TodoItem({
    required this.title,
    this.isDone = false,
  });
}
