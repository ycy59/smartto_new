import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/today_plan_provider.dart';
import '../providers/stats_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'subject_page.dart';
import 'my_page.dart';
import 'camera_page.dart';
import 'report_page.dart';
import '../providers/theme_provider.dart';


class MainScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_TodayPlanCardState> _todayPlanKey =
      GlobalKey<_TodayPlanCardState>();

  late String _nickname;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname;
    _profileImagePath = widget.profileImagePath;
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
    final isDark = ref.read(themeProvider) == ThemeMode.dark; // ✅ 추가

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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // ✅
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
                Text(                         // ✅ const 제거
                  '시작하시겠습니까?',
                  style: TextStyle(           // ✅ const 제거
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF232323), // ✅
                  ),
                ),
                const SizedBox(height: 12),
                Text(                         // ✅ const 제거
                  '집중 모드를 시작합니다.\n카메라로 집중도를 측정합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(           // ✅ const 제거
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? const Color(0xFF888888) : const Color(0xFF8F8F8F), // ✅
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
                            side: BorderSide(  // ✅ const 제거
                              color: isDark ? const Color(0xFF444444) : const Color(0xFFE5E5E5), // ✅
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F8), // ✅
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
    if (!mounted) return;

    final cameraTasks = _todayPlanKey.currentState?.getCameraTasks() ?? [];

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(allTasks: cameraTasks),
      ),
    );

    if (!mounted) return;
    _todayPlanKey.currentState?._loadTodayPlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: ref.watch(themeProvider) == ThemeMode.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF7F4F2),
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
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _FadeSlideIn(
                              child: GreetingCard(nickname: _nickname),
                            ),
                            const SizedBox(height: 16),
                            const _FadeSlideIn(
                              delay: Duration(milliseconds: 90),
                              child: WeeklyStatsCard(),
                            ),
                            const SizedBox(height: 16),
                            _FadeSlideIn(
                              delay: const Duration(milliseconds: 180),
                              child: TodayPlanCard(
                                key: _todayPlanKey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const PageIndicatorDots(),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AppBottomNavBar(
                    activeTab: AppNavTab.home,
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
    );
  }
}

// ─────────────────────────────────────────────
// GreetingCard
// ─────────────────────────────────────────────
class GreetingCard extends ConsumerWidget {
  final String nickname;

  const GreetingCard({
    super.key,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = nickname.trim();
    final statsAsync = ref.watch(statsProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark; // ✅ 수정

    final todayLabel = statsAsync.when(
      data: (s) => formatMinutes(s.todayMinutes),
      loading: () => '--',
      error: (_, __) => '--',
    );
    final goalLabel = statsAsync.when(
      data: (s) => formatMinutes(s.goalMinutes),
      loading: () => '--',
      error: (_, __) => '--',
    );
    final progress = statsAsync.when(
      data: (s) => s.goalMinutes > 0
          ? (s.todayMinutes / s.goalMinutes).clamp(0.0, 1.0)
          : 0.0,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
    final progressPct = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName.isEmpty ? '안녕하세요!' : '안녕하세요 $displayName님',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF8A8A8A),
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '오늘도 스마트하게',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Consumer(
                builder: (context, ref, _) {
                  final isDark = ref.watch(themeProvider) == ThemeMode.dark;
                  return GestureDetector(
                    onTap: () => ref.read(themeProvider.notifier).toggle(),
                    child: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: const Color(0xFF9E9E9E),
                      size: 20,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: InfoCard(
                  isDark: isDark,
                  title: '학습 시간',
                  value: todayLabel,
                  changeText: '$progressPct%',
                  changeColor: const Color(0xFFD97068),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  isDark: isDark, // ✅ 추가
                  title: '목표 시간',
                  value: goalLabel,
                  changeText: '오늘 목표',
                  changeColor: const Color(0xFF6D88D8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// InfoCard
// ─────────────────────────────────────────────
class InfoCard extends StatelessWidget {
  final bool isDark; // ✅ 추가
  final String title;
  final String value;
  final String changeText;
  final Color changeColor;

  const InfoCard({
    super.key,
    required this.isDark, // ✅ 추가
    required this.title,
    required this.value,
    required this.changeText,
    required this.changeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF252525)
            : const Color(0xFFFAF7F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF323232)
              : const Color(0xFFF0EBEA),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF9A9A9A)
                        : const Color(0xFF8A8A8A),
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _AnimatedValueText(
                  value: changeText,
                  style: TextStyle(
                    fontSize: 10,
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          _AnimatedValueText(
            value: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WeeklyStatsCard
// ─────────────────────────────────────────────
class WeeklyStatsCard extends ConsumerWidget {
  const WeeklyStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark; // ✅ 수정

    final totalFocus = statsAsync.when(
      data: (s) => formatMinutes(s.weeklyMinutes),
      loading: () => '--',
      error: (_, __) => '--',
    );
    final sessionCount = statsAsync.when(
      data: (s) => '${s.weeklySessionCount}개',
      loading: () => '--',
      error: (_, __) => '--',
    );
    final avgFocus = statsAsync.when(
      data: (s) => s.weeklyAvgFocus != null
          ? '${s.weeklyAvgFocus!.toInt()}%'
          : '-%',
      loading: () => '--',
      error: (_, __) => '--',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '이번주 통계',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              _PressableScale(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportPageShell(
                        currentIndex: 3,
                        onTapNav: (_) {},
                        nickname: '',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A2A28)
                        : const Color(0xFFFDF2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '상세 보기',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97068),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatItem(
                isDark: isDark, // ✅ 추가
                circleColor: const Color(0xFFF1D1CC),
                iconColor: const Color(0xFFC96B63),
                icon: Icons.timer,
                value: totalFocus,
                label: '총 집중',
              ),
              StatItem(
                isDark: isDark, // ✅ 추가
                circleColor: const Color(0xFFDCE9CE),
                iconColor: const Color(0xFF789F57),
                icon: Icons.check_circle,
                value: sessionCount,
                label: '완료 세션',
              ),
              StatItem(
                isDark: isDark, // ✅ 추가
                circleColor: const Color(0xFFF4DEAE),
                iconColor: const Color(0xFFD9A247),
                icon: Icons.group_work_rounded,
                value: avgFocus,
                label: '평균 집중도',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// StatItem
// ─────────────────────────────────────────────
class StatItem extends StatelessWidget {
  final bool isDark; // ✅ 추가
  final Color circleColor;
  final Color iconColor;
  final IconData icon;
  final String value;
  final String label;

  const StatItem({
    super.key,
    required this.isDark, // ✅ 추가
    required this.circleColor,
    required this.iconColor,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          _AnimatedValueText(
            value: value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: isDark
                  ? const Color(0xFF9A9A9A)
                  : const Color(0xFF8A8A8A),
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TodayPlanCard
// ─────────────────────────────────────────────
class TodayPlanCard extends ConsumerStatefulWidget {
  const TodayPlanCard({
    super.key,
  });

  @override
  ConsumerState<TodayPlanCard> createState() => _TodayPlanCardState();
}

class _TodayPlanCardState extends ConsumerState<TodayPlanCard> {
  final bool _isEditing = false;
  int? _paletteOpenIndex;
  List<MainPlanSubject> _subjects = [];

  final List<Color> _subjectColors = const [
    Color(0xFFE06B63),
    Color(0xFF79B13D),
    Color(0xFF7B89FF),
    Color(0xFF9F88FF),
    Color(0xFFF0C06F),
    Color(0xFFF08AA1),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayPlan());
  }

  Future<void> _loadTodayPlan() async {
    ref.invalidate(todayPlanProvider);
    final entries = await ref.read(todayPlanProvider.future);
    if (!mounted) return;
    setState(() => _subjects = _mapEntries(entries));
  }

  List<MainPlanSubject> _mapEntries(List<TodayPlanEntry> entries) =>
      entries.map((e) {
        final dday = e.goal.daysUntilDeadline ?? 0;
        return MainPlanSubject(
          subjectId: e.subject.id,
          goalId: e.goal.id,
          title: e.subject.name,
          color: e.subject.color,
          dday: dday < 0 ? 0 : dday,
          todos: e.goal.todos
              .map((t) => MainPlanTodo(
                    id: t.id,
                    text: t.text,
                    done: t.isDone,
                    priority: t.priority,
                    dueDate: t.dueDate,
                  ))
              .toList(),
        );
      }).toList();

  List<CameraTask> getCameraTasks() {
    final result = <CameraTask>[];
    for (final subject in _subjects) {
      if (subject.goalId == null) continue;
      for (final todo in subject.todos) {
        if (todo.text.isNotEmpty) {
          result.add(CameraTask(
            todoId: todo.id ?? '',
            goalId: subject.goalId!,
            subjectId: subject.subjectId ?? '',
            text: todo.text,
            subjectName: subject.title,
            subjectColor: subject.color,
          ));
        }
      }
    }
    return result;
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
    ref.listen(todayPlanProvider, (_, next) {
      next.whenData((entries) {
        if (mounted && !_isEditing) {
          setState(() => _subjects = _mapEntries(entries));
        }
      });
    });

    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '오늘의 계획',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              _PressableScale(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SubjectPageShell(
                        currentIndex: 2,
                        onTapNav: (_) {},
                        nickname: '',
                      ),
                    ),
                  );
                  _loadTodayPlan();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A2A28)
                        : const Color(0xFFFDF2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '편집',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97068),
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_subjects.length, (subjectIndex) {
            final subject = _subjects[subjectIndex];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _EditableSubjectBlock(
                isDark: isDark,
                subject: subject,
                isEditing: _isEditing,
                showPalette: _paletteOpenIndex == subjectIndex,
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

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────
class MainPlanSubject {
  final String? subjectId;
  final String? goalId;
  String title;
  Color color;
  int dday;
  List<MainPlanTodo> todos;

  MainPlanSubject({
    this.subjectId,
    this.goalId,
    required this.title,
    required this.color,
    required this.dday,
    required this.todos,
  });
}

class MainPlanTodo {
  final String? id;
  String text;
  bool done;
  int priority;
  DateTime? dueDate;

  MainPlanTodo({
    this.id,
    required this.text,
    required this.done,
    this.priority = 0,
    this.dueDate,
  });
}

// ─────────────────────────────────────────────
// _EditableSubjectBlock
// ─────────────────────────────────────────────
class _EditableSubjectBlock extends StatelessWidget {
  final bool isDark;
  final MainPlanSubject subject;
  final bool isEditing;
  final bool showPalette;
  final VoidCallback onTogglePalette;
  final List<Color> subjectColors;
  final VoidCallback onDeleteSubject;
  final ValueChanged<Color> onPickColor;
  final ValueChanged<String> onChangedTitle;
  final ValueChanged<String> onChangedDday;
  final ValueChanged<int> onRemoveTodo;
  final ValueChanged<int> onSubmittedTodo;
  final void Function(int, String) onChangedTodo;

  String _getDdayText(MainPlanSubject subject) {
    DateTime? earliest;
    for (final todo in subject.todos) {
      if (todo.dueDate != null) {
        if (earliest == null || todo.dueDate!.isBefore(earliest)) {
          earliest = todo.dueDate;
        }
      }
    }

    if (earliest == null) return 'D - ${subject.dday}';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(earliest.year, earliest.month, earliest.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return 'D + ${diff.abs()}';
    if (diff == 0) return 'D - 0';
    return 'D - $diff';
  }

  const _EditableSubjectBlock({
    required this.isDark,
    required this.subject,
    required this.isEditing,
    required this.showPalette,
    required this.onTogglePalette,
    required this.subjectColors,
    required this.onDeleteSubject,
    required this.onPickColor,
    required this.onChangedTitle,
    required this.onChangedDday,
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
                      style: TextStyle( // ✅ const 제거
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : Text(
                      subject.title,
                      style: TextStyle( // ✅ const 제거
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
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
            ],
            const SizedBox(width: 8),
            if (subject.todos.any((t) => t.dueDate != null))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF4A3535) : const Color(0xFFF2E1E2), // ✅ 다크모드 색상
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
                        _getDdayText(subject),
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

          return Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
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
                              color: isDark
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF8A8A8A),
                            ),
                          )
                        : Text(
                            todo.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFAAAAAA) // ✅ 다크모드 할일 텍스트
                                  : const Color(0xFF8A8A8A),
                              fontWeight: FontWeight.w500,
                            ),
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
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// _FadeSlideIn — mount 시 살짝 위로 슬라이드 + 페이드인
// ─────────────────────────────────────────────
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeSlideIn({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _PressableScale — 탭 시 살짝 축소되며 tactile 피드백
// ─────────────────────────────────────────────
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableScale({
    required this.child,
    this.onTap,
  });

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _AnimatedValueText — 값 바뀔 때 슬라이드+페이드 전환
// ─────────────────────────────────────────────
class _AnimatedValueText extends StatelessWidget {
  final String value;
  final TextStyle? style;

  const _AnimatedValueText({
    required this.value,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PageIndicatorDots
// ─────────────────────────────────────────────
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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

