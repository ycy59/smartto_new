import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../algorithms/fsrs/fsrs_engine.dart';
import '../domain/entities/subject.dart' as domain;
import '../domain/entities/study_goal.dart';
import '../domain/entities/todo_item.dart' as domain;
import '../providers/database_provider.dart';
import '../providers/today_plan_provider.dart';
import 'camera_page.dart';
import 'calendar_page.dart';
import 'main_screen.dart';
import 'report_page.dart';

/// 앱 전체에서 사용하는 과목 색상 팔레트
const kSubjectColorPalette = [
  Color(0xFF7B89FF),
  Color(0xFF9F88FF),
  Color(0xFF8BCF6E),
  Color(0xFFF0C06F),
  Color(0xFFF08AA1),
  Color(0xFF90C4FF),
  Color(0xFFE06B63),
  Color(0xFF79B13D),
  Color(0xFFFFB347),
  Color(0xFF66CDAA),
];

enum SubjectPageMode {
  empty,
  add,
  list,
  detail,
}

class SubjectPageShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;

  const SubjectPageShell({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
    required this.nickname,
    this.profileImagePath,
  });

  @override
  ConsumerState<SubjectPageShell> createState() => _SubjectPageShellState();
}

class _SubjectPageShellState extends ConsumerState<SubjectPageShell> {
  List<SubjectItem> _subjects = [];

  SubjectPageMode _mode = SubjectPageMode.empty;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _loadSubjectsFromDb();
  }

  Future<void> _loadSubjectsFromDb() async {
    final subjectRepo = ref.read(subjectRepoProvider);
    final goalRepo = ref.read(studyGoalRepoProvider);

    final subjects = await subjectRepo.getAll();
    final result = <SubjectItem>[];

    for (final subject in subjects) {
      final goals = await goalRepo.getBySubject(subject.id);
      if (goals.isEmpty) continue;
      final goal = goals.first;
      result.add(SubjectItem(
        subjectId: subject.id,
        goalId: goal.id,
        name: subject.name,
        mode: goal.mode,
        date: goal.dueDate ?? DateTime.now(),
        level: goal.understandingLevel,
        color: subject.color,
        todos: goal.todos
            .map((t) => TodoItem(id: t.id, text: t.text, done: t.isDone))
            .toList(),
      ));
    }

    if (!mounted) return;
    setState(() {
      _subjects = result;
      _mode = result.isEmpty ? SubjectPageMode.empty : SubjectPageMode.list;
    });
  }

  Future<void> _saveSubjectToDb(SubjectItem item) async {
    const uuid = Uuid();
    final subjectRepo = ref.read(subjectRepoProvider);
    final goalRepo = ref.read(studyGoalRepoProvider);
    final todoRepo = ref.read(todoRepoProvider);

    final subjectId = item.subjectId ?? uuid.v4();
    final goalId = item.goalId ?? uuid.v4();

    await subjectRepo.save(domain.Subject(
      id: subjectId,
      name: item.name,
      color: item.color,
    ));

    if (item.goalId == null) {
      final fsrs = FsrsEngine.initFromLevel(item.level.toDbString());
      await goalRepo.save(StudyGoal(
        id: goalId,
        subjectId: subjectId,
        title: item.name,
        mode: item.mode,
        understandingLevel: item.level,
        dueDate: item.date,
        stability: fsrs.stability,
        difficulty: fsrs.difficulty,
        retrievability: fsrs.retrievability,
        repetitions: fsrs.repetitions,
        state: fsrs.state,
        lastReview: fsrs.lastReview,
        nextDue: fsrs.nextDue,
        createdAt: DateTime.now(),
      ));
    } else {
      final existing = await goalRepo.getById(goalId);
      if (existing != null) {
        await goalRepo.save(existing.copyWith(
          title: item.name,
          mode: item.mode,
          dueDate: () => item.date,
          understandingLevel: item.level,
        ));
        await todoRepo.deleteByGoal(goalId);
      }
    }

    for (int i = 0; i < item.todos.length; i++) {
      final t = item.todos[i];
      if (t.text.isNotEmpty) {
        await todoRepo.save(domain.TodoItem(
          id: t.id ?? uuid.v4(),
          goalId: goalId,
          text: t.text,
          isDone: t.done,
          position: i,
        ));
      }
    }

    ref.read(todayPlanProvider.notifier).refresh();
  }

  Future<void> _showStartDialog() async {
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
                          foregroundColor: const Color(0xFF9A9A9A),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '시작',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
  if (!mounted) return;

  // 현재 화면의 과목 할일을 CameraTask로 변환
  final cameraTasks = _subjects
      .where((s) => s.goalId != null && s.subjectId != null)
      .expand((s) => s.todos
          .where((t) => t.text.isNotEmpty)
          .map((t) => CameraTask(
                todoId: t.id ?? '',
                goalId: s.goalId!,
                subjectId: s.subjectId!,
                text: t.text,
              )))
      .toList();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CameraPage(
        initialSelectedTask: null,
        allTasks: cameraTasks,
      ),
    ),
  );
}

  /// 현재 사용 중이지 않은 색상을 랜덤 선택
  Color _pickUnusedColor() {
    final used = _subjects.map((s) => s.color.value).toSet();
    final unused = kSubjectColorPalette
        .where((c) => !used.contains(c.value))
        .toList();
    if (unused.isEmpty) {
      // 팔레트 색상을 모두 사용한 경우 전체에서 랜덤
      return kSubjectColorPalette[Random().nextInt(kSubjectColorPalette.length)];
    }
    unused.shuffle(Random());
    return unused.first;
  }

  void _openAddScreen() {
    setState(() {
      _mode = SubjectPageMode.add;
      _selectedIndex = null;
    });
  }

  void _openListScreen() {
    setState(() {
      _mode = _subjects.isEmpty ? SubjectPageMode.empty : SubjectPageMode.list;
      _selectedIndex = null;
    });
  }

  void _addSubject(SubjectItem item) {
    _saveSubjectToDb(item);
    setState(() {
      _subjects.add(item);
      _mode = SubjectPageMode.list;
      _selectedIndex = null;
    });
  }

  void _openDetailScreen(int index) {
    setState(() {
      _selectedIndex = index;
      _mode = SubjectPageMode.detail;
    });
  }

  void _updateSubject(int index, SubjectItem updated) {
    final original = _subjects[index];
    final withIds = SubjectItem(
      subjectId: original.subjectId,
      goalId: original.goalId,
      name: updated.name,
      mode: updated.mode,
      date: updated.date,
      level: updated.level,
      color: updated.color,
      todos: updated.todos,
    );
    _saveSubjectToDb(withIds);
    setState(() {
      _subjects[index] = withIds;
      _mode = SubjectPageMode.list;
      _selectedIndex = null;
    });
  }

  void _deleteSubject(int index) {
    final item = _subjects[index];
    if (item.subjectId != null) {
      ref.read(subjectRepoProvider).delete(item.subjectId!);
      ref.read(todayPlanProvider.notifier).refresh();
    }
    setState(() {
      _subjects.removeAt(index);
      _mode = _subjects.isEmpty ? SubjectPageMode.empty : SubjectPageMode.list;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_mode == SubjectPageMode.empty) {
      body = SubjectEmptyPage(
        onAddTap: _openAddScreen,
      );
    } else if (_mode == SubjectPageMode.add) {
      body = SubjectAddPage(
        onCancel: _openListScreen,
        onComplete: _addSubject,
        defaultColor: _pickUnusedColor(),
      );
    } else if (_mode == SubjectPageMode.detail && _selectedIndex != null) {
      body = SubjectDetailPage(
        subject: _subjects[_selectedIndex!],
        onBack: _openListScreen,
        onSave: (updated) => _updateSubject(_selectedIndex!, updated),
      );
    } else {
      body = SubjectListPage(
        subjects: _subjects,
        onAddTap: _openAddScreen,
        onDetailTap: _openDetailScreen,
        onDelete: _deleteSubject,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(child: body),
                SubjectBottomNavBar(
                  currentIndex: widget.currentIndex,
                  onTapNav: widget.onTapNav,
                  nickname: widget.nickname,
                  profileImagePath: widget.profileImagePath,
                  onTapTomato: _showStartDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubjectEmptyPage extends StatelessWidget {
  final VoidCallback onAddTap;

  const SubjectEmptyPage({
    super.key,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '과목 추가하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB2B2B2),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFF6E1DF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.add,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ──────────────────────────────────────────
// 과목 목록 화면
// ──────────────────────────────────────────
class SubjectListPage extends StatelessWidget {
  final List<SubjectItem> subjects;
  final VoidCallback onAddTap;
  final ValueChanged<int> onDetailTap;
  final ValueChanged<int> onDelete;

  const SubjectListPage({
    super.key,
    required this.subjects,
    required this.onAddTap,
    required this.onDetailTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ 과목이 없으면 빈 화면 (+ 버튼만)
    if (subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '과목 추가하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB2B2B2),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E1DF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.add,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ 과목이 있으면 리스트 + 하단 + 버튼
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Stack(
        children: [
          ListView.separated(
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = subjects[index];

              return Dismissible(
                key: ValueKey('${item.name}-$index'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => onDelete(index),
                background: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD96C5F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 18),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                child: _SubjectRow(
                  item: item,
                  onDetailTap: () => onDetailTap(index),
                ),
              );
            },
          ),
          // ✅ 우하단 + 버튼
          Positioned(
            right: 0,
            bottom: 12,
            child: GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E1DF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final SubjectItem item;
  final VoidCallback onDetailTap;

  const _SubjectRow({
    required this.item,
    required this.onDetailTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF303030),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDetailTap,
            child: const Text(
                'Detail',
                style: TextStyle(
                color: Color(0xFFB7B7B7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
            ),
         ),
     ),
     const SizedBox(width: 6),
     GestureDetector(
      onTap: onDetailTap,
      child: const Icon(
        Icons.chevron_right,
        color: Color(0xFFC7C7C7),
      ),
     ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 과목 추가 화면
// ──────────────────────────────────────────
class SubjectAddPage extends StatefulWidget {
  final VoidCallback onCancel;
  final ValueChanged<SubjectItem> onComplete;
  final Color defaultColor;

  const SubjectAddPage({
    super.key,
    required this.onCancel,
    required this.onComplete,
    required this.defaultColor,
  });

  @override
  State<SubjectAddPage> createState() => _SubjectAddPageState();
}

class _SubjectAddPageState extends State<SubjectAddPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  StudyMode? _selectedMode;
  UnderstandingLevel? _selectedLevel;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  bool get _canComplete {
    return _nameController.text.trim().isNotEmpty &&
        _selectedMode != null &&
        _selectedDate != null &&
        _selectedLevel != null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _dateController.text =
          '${picked.year}. ${picked.month.toString().padLeft(2, '0')}. ${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _submit() {
    if (!_canComplete) return;

    widget.onComplete(
      SubjectItem(
        name: _nameController.text.trim(),
        mode: _selectedMode!,
        date: _selectedDate!,
        level: _selectedLevel!,
        color: widget.defaultColor,
        todos: [
            TodoItem(text: '', done: false),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _selectedMode == StudyMode.study ? '학습일자' : '시험일자';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 핸들
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D0D0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 이름 설정
            const Text('이름 설정',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFEFD), // ✅ 변경
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6E2D8)), // ✅ 변경
              ),
              child: TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '입력',
                  hintStyle:
                      TextStyle(color: Color(0xFFBEBEBE), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 모드 설정
            const Text('모드 설정',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    title: '학습 모드',
                    selected: _selectedMode == StudyMode.study,
                    onTap: () => setState(() => _selectedMode = StudyMode.study),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ModeButton(
                    title: '시험 모드',
                    selected: _selectedMode == StudyMode.exam,
                    onTap: () => setState(() => _selectedMode = StudyMode.exam),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 날짜
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectedMode == null ? null : _pickDate,
              child: AbsorbPointer(
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE7DED1)),
                  ),
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14),
                      hintText: '날짜 선택',
                      hintStyle: TextStyle(
                          color: Color(0xFFBEBEBE), fontSize: 14),
                    ),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF444444)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 이해도
            const Text('이해도',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LevelButton(
                    title: '어려움',
                    background: const Color(0xFFF08AA1),
                    selected: _selectedLevel == UnderstandingLevel.hard,
                    onTap: () =>
                        setState(() => _selectedLevel = UnderstandingLevel.hard),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LevelButton(
                    title: '보통',
                    background: const Color(0xFFF0C06F),
                    selected: _selectedLevel == UnderstandingLevel.normal,
                    onTap: () => setState(
                        () => _selectedLevel = UnderstandingLevel.normal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LevelButton(
                    title: '쉬움',
                    background: const Color(0xFF97D778),
                    selected: _selectedLevel == UnderstandingLevel.easy,
                    onTap: () =>
                        setState(() => _selectedLevel = UnderstandingLevel.easy),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // 완료 버튼
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _canComplete ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF299B2),
                  disabledBackgroundColor: const Color(0xFFF0D8DF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectDetailPage extends StatefulWidget {
  final SubjectItem subject;
  final VoidCallback onBack;
  final ValueChanged<SubjectItem> onSave;

  const SubjectDetailPage({
    super.key,
    required this.subject,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  late TextEditingController _nameController;
  late StudyMode _mode;
  late UnderstandingLevel _level;
  late DateTime _date;
  late Color _selectedColor;
  late List<TodoItem> _todos;
  late List<TextEditingController> _todoControllers;

  bool _showColorPalette = false;

  final List<Color> _colorOptions = const [
    Color(0xFF7B89FF),
    Color(0xFF9F88FF),
    Color(0xFF8BCF6E),
    Color(0xFFF0C06F),
    Color(0xFFF08AA1),
    Color(0xFF90C4FF),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.subject.name);
    _mode = widget.subject.mode;
    _level = widget.subject.level;
    _date = widget.subject.date;
    _selectedColor = widget.subject.color;
    _todos = widget.subject.todos.isEmpty
        ? [TodoItem(text: '', done: false)]
        : widget.subject.todos
            .map((e) => TodoItem(text: e.text, done: e.done))
            .toList();

    _todoControllers =
        _todos.map((e) => TextEditingController(text: e.text)).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _todoControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(_date.year, _date.month, _date.day);
    return target.difference(today).inDays;
  }

  Color get _levelColor {
    switch (_level) {
      case UnderstandingLevel.hard:
        return const Color(0xFFF08AA1);
      case UnderstandingLevel.normal:
        return const Color(0xFFF0C06F);
      case UnderstandingLevel.easy:
        return const Color(0xFF97D778);
    }
  }

  String get _levelText {
    switch (_level) {
      case UnderstandingLevel.hard:
        return '어려움';
      case UnderstandingLevel.normal:
        return '보통';
      case UnderstandingLevel.easy:
        return '쉬움';
    }
  }

  Color _softBackground(Color color) {
  return Color.lerp(color, Colors.white, 0.88)!;
}

  void _insertNextTodo(int index) {
    setState(() {
      _todos.insert(index + 1, TodoItem(text: '', done: false));
      _todoControllers.insert(index + 1, TextEditingController());
    });
  }

  void _save() {
    final cleanedTodos = <TodoItem>[];
    for (int i = 0; i < _todoControllers.length; i++) {
      final text = _todoControllers[i].text.trim();
      if (text.isNotEmpty) {
        cleanedTodos.add(
          TodoItem(
            text: text,
            done: _todos[i].done,
          ),
        );
      }
    }

    widget.onSave(
      SubjectItem(
        name: _nameController.text.trim(),
        mode: _mode,
        date: _date,
        level: _level,
        color: _selectedColor,
        todos: cleanedTodos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showColorPalette = !_showColorPalette;
                        });
                      },
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Color(0xFF9B9B9B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_showColorPalette) ...[
  const SizedBox(height: 6),
  Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: _colorOptions.map((color) {
      final selected = _selectedColor == color;

      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedColor = color;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
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
const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFB2B2B2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _softBackground(_selectedColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  _nameController.text.trim().isEmpty
                                      ? '과목'
                                      : _nameController.text.trim(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _levelColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _levelText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB8DE9D),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'D-${_dDay < 0 ? 0 : _dDay + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: List.generate(_todoControllers.length, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _todos[index].done = !_todos[index].done;
                                          });
                                        },
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: _todos[index].done
                                                ? _selectedColor
                                                : const Color(0xFFE0E0E0),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _todoControllers[index],
                                          onChanged: (value) {
                                            _todos[index].text = value;
                                          },
                                          onSubmitted: (_) {
                                            _insertNextTodo(index);
                                          },
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFFD9D9D9),
                                              ),
                                            ),
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFFD9D9D9),
                                              ),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Color(0xFFBDBDBD),
                                              ),
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF299B2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 공통 위젯들
// ──────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 106,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6E1DF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3DDD5)),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF666666)),
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String title;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  const _LevelButton({
    required this.title,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1.0 : 0.72,
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFF8D8D8D), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 하단 네비게이션 바
// ──────────────────────────────────────────
class SubjectBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;
  final VoidCallback onTapTomato;

  const SubjectBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
    required this.nickname,
    this.profileImagePath,
    required this.onTapTomato,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F0F0),
        border: Border(top: BorderSide(color: Color(0xFFE9E9E9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavIcon(
            icon: Icons.home,
            label: 'Home',
            active: false,
            onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => MainScreen(
                      nickname: nickname,
                      profileImagePath: profileImagePath,
                      currentIndex: 0,
                      onTapNav: onTapNav,
                    ),
                  ),
                  (route) => false,
                );
            },
          ),
            _BottomNavIcon(
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
          _BottomTomatoItem(onTap: onTapTomato),
          _BottomNavIcon(
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
          _BottomNavIcon(
            icon: Icons.book,
            label: 'Subject',
            active: currentIndex == 2,
            onTap: () => onTapNav(2),
          ),
        ],
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFE08C84) : const Color(0xFFC8C8C8);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _BottomTomatoItem extends StatelessWidget {
  final VoidCallback onTap;

  const _BottomTomatoItem({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFFD94C43),
                child: const Center(
                  child: Text('🍅', style: TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 데이터 모델 (StudyMode, UnderstandingLevel은 domain/entities/study_goal.dart에서 import)
// ──────────────────────────────────────────

class SubjectItem {
  final String? subjectId; // DB Subject ID (null = 미저장)
  final String? goalId;    // DB StudyGoal ID (null = 미저장)
  final String name;
  final StudyMode mode;
  final DateTime date;
  final UnderstandingLevel level;
  final Color color;
  final List<TodoItem> todos;

  SubjectItem({
    this.subjectId,
    this.goalId,
    required this.name,
    required this.mode,
    required this.date,
    required this.level,
    required this.color,
    required this.todos,
  });

  int get dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }
}

class TodoItem {
  final String? id; // DB todo_items ID (null = 미저장)
  String text;
  bool done;

  TodoItem({
    this.id,
    required this.text,
    required this.done,
  });
}