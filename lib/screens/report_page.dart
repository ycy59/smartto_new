import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';
import '../providers/today_plan_provider.dart';
import '../providers/theme_provider.dart'; // ✅ 추가
import '../widgets/app_bottom_nav_bar.dart';
import 'camera_page.dart';
import 'dart:io';
import '../providers/slm_provider.dart';
import '../widgets/prompts/slm_prompts.dart';

const Duration _kInsightUiUpdateInterval = Duration(milliseconds: 120);

// ─────────────────────────────────────────────
// 동적 효과 헬퍼 (file-private)
// ─────────────────────────────────────────────
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

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

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableScale({required this.child, this.onTap});

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
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedValueText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  const _AnimatedValueText({required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}

class ReportPageShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;

  const ReportPageShell({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
    required this.nickname,
    this.profileImagePath,
  });

  @override
  ConsumerState<ReportPageShell> createState() => _ReportPageShellState();
}

class _ReportPageShellState extends ConsumerState<ReportPageShell>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showStartDialog() async {
    final isDark = ref.read(themeProvider) == ThemeMode.dark; // ✅

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
                Text(
                  '시작하시겠습니까?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF232323), // ✅
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '집중 모드를 시작합니다.\n카메라로 집중도를 측정합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFF8F8F8F), // ✅
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
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF444444)
                                  : const Color(0xFFE5E5E5), // ✅
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF8F8F8), // ✅
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

    final entries = await ref.read(todayPlanProvider.future);
    final tasks = CameraTask.fromTodayPlan(entries);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(allTasks: tasks),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark; // ✅

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2), // ✅
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFE8E8E8), // ✅
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3A3A3A)
                            : Colors.white, // ✅
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: isDark ? Colors.white : Colors.black, // ✅
                      unselectedLabelColor: const Color(0xFF9E9E9E),
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: const [Tab(text: '일간'), Tab(text: '주간')],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DailyTab(isDark: isDark), // ✅
                      _WeeklyTab(isDark: isDark), // ✅
                    ],
                  ),
                ),
                AppBottomNavBar(
                  activeTab: AppNavTab.report,
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

// ─────────────────────────────────────────────────────────
// 일간 탭
// ─────────────────────────────────────────────────────────
class _DailyTab extends ConsumerStatefulWidget {
  final bool isDark; // ✅

  const _DailyTab({required this.isDark}); // ✅

  @override
  ConsumerState<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends ConsumerState<_DailyTab> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime _selectedDate = _stripTime(DateTime.now());
  String? _insightText;
  bool _insightLoading = false;

  static DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  void _changeDate(int delta) {
    final next = _selectedDate.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = _stripTime(next);
      _insightText = null;
      _insightLoading = false;
    });
  }

  String _formatDateLabel(DateTime d) {
    final now = _stripTime(DateTime.now());
    if (d == now) return '오늘';
    if (d == now.subtract(const Duration(days: 1))) return '어제';
    return '${d.month}/${d.day}';
  }

  Future<void> _generateDailyInsight({
    required DailyReport report,
    required List<HourlyBucket> buckets,
    required List<ActivityEntry> activities,
    required ModeRatio ratio,
  }) async {
    if (_insightLoading) return;
    setState(() {
      _insightLoading = true;
      _insightText = null;
    });
    final now = _stripTime(DateTime.now());
    final period = _selectedDate == now
        ? '오늘'
        : '${_selectedDate.month}월 ${_selectedDate.day}일';
    final withFocus =
        buckets.where((b) => b.avgFocus != null && b.minutes >= 10).toList();
    String bestSlot = '-', weakSlot = '-';
    if (withFocus.isNotEmpty) {
      final best = withFocus
          .reduce((a, b) => (a.avgFocus ?? 0) > (b.avgFocus ?? 0) ? a : b);
      final weak = withFocus
          .reduce((a, b) => (a.avgFocus ?? 100) < (b.avgFocus ?? 100) ? a : b);
      String fmt(int h) =>
          '${h >= 12 ? '오후' : '오전'} ${h == 0 ? 12 : h > 12 ? h - 12 : h}시';
      bestSlot = fmt(best.hour);
      weakSlot = fmt(weak.hour);
    }
    final subjectMinMap = <String, int>{};
    final subjectFocusWeightMap = <String, double>{};
    final subjectFocusMinMap = <String, int>{};
    final subjectNameMap = <String, String>{};
    for (final b in buckets) {
      subjectMinMap[b.subjectId] =
          (subjectMinMap[b.subjectId] ?? 0) + b.minutes;
      subjectNameMap[b.subjectId] = b.subjectName;
      if (b.avgFocus != null && b.minutes > 0) {
        subjectFocusWeightMap[b.subjectId] =
            (subjectFocusWeightMap[b.subjectId] ?? 0.0) +
                b.avgFocus! * b.minutes;
        subjectFocusMinMap[b.subjectId] =
            (subjectFocusMinMap[b.subjectId] ?? 0) + b.minutes;
      }
    }
    String mostStudied = '-', lowestFocus = '-';
    if (subjectMinMap.isNotEmpty) {
      final maxId =
          subjectMinMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      mostStudied = subjectNameMap[maxId] ?? '-';
    }
    if (subjectFocusMinMap.isNotEmpty) {
      final avgMap = subjectFocusMinMap
          .map((id, mins) => MapEntry(id, subjectFocusWeightMap[id]! / mins));
      final minId =
          avgMap.entries.reduce((a, b) => a.value < b.value ? a : b).key;
      lowestFocus = subjectNameMap[minId] ?? '-';
    }
    final modeStr = ratio.totalMinutes > 0
        ? '학습 ${(ratio.studyRatio * 100).toInt()}%, 시험 ${(ratio.examRatio * 100).toInt()}%'
        : '-';
    final prompt = SlmPrompts.reportInsight(
      period: period,
      totalStudyTime: formatMinutesKo(report.totalMinutes),
      completedTodos: report.completedTodos,
      averageFocusPercent: report.avgFocus?.toInt() ?? 0,
      totalSessions: activities.length,
      bestFocusTimeSlot: bestSlot,
      weakFocusTimeSlot: weakSlot,
      mostStudiedSubject: mostStudied,
      lowestFocusSubject: lowestFocus,
      studyModeRatio: modeStr,
    );
    try {
      final slm = ref.read(slmServiceProvider);
      await slm.load();
      await slm.resetSession();
      final buf = StringBuffer();
      final uiUpdateClock = Stopwatch()..start();
      await for (final token in slm.generate(prompt)) {
        buf.write(token);
        if (mounted && uiUpdateClock.elapsed >= _kInsightUiUpdateInterval) {
          uiUpdateClock.reset();
          setState(() => _insightText = buf.toString());
        }
      }
      if (mounted) setState(() => _insightText = buf.toString());
    } catch (e) {
      if (mounted) setState(() => _insightText = SlmPrompts.fallbackCoaching);
    } finally {
      if (mounted) setState(() => _insightLoading = false);
    }
  }

  Widget _buildDailyInsightCard(
    bool isDark,
    DailyReport report,
    List<HourlyBucket> buckets,
    List<ActivityEntry> activities,
    ModeRatio ratio,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B89FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('AI',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7B89FF))),
              ),
              const SizedBox(width: 8),
              Text(
                '학습 인사이트',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_insightText != null)
            Text(
              _insightText!,
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444),
                height: 1.6,
              ),
            )
          else if (_insightLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!Platform.isIOS && !Platform.isAndroid)
            Text(
              'iOS/Android에서만 지원됩니다.',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF666666) : Colors.grey),
            )
          else
            GestureDetector(
              onTap: () => _generateDailyInsight(
                report: report,
                buckets: buckets,
                activities: activities,
                ratio: ratio,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B89FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '인사이트 생성',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark; // ✅
    final dailyReport = ref.watch(dailyReportProvider(_selectedDate));
    final hourlyBuckets = ref.watch(dailyHourlyBucketsProvider(_selectedDate));
    final modeRatio = ref.watch(dailyModeRatioProvider(_selectedDate));
    final activities = ref.watch(dailyActivitiesProvider(_selectedDate));

    return Column(
      children: [
        // 날짜 네비게이터
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PressableScale(
                onTap: () => _changeDate(-1),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.chevron_left, color: Color(0xFFAAAAAA)),
                ),
              ),
              const SizedBox(width: 12),
              _AnimatedValueText(
                value: _formatDateLabel(_selectedDate),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 12),
              _PressableScale(
                onTap: () => _changeDate(1),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_right,
                    color: _selectedDate == _stripTime(DateTime.now())
                        ? const Color(0xFFDDDDDD)
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 통계 카드 3종
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: dailyReport.when(
            data: (report) => Row(
              children: [
                Expanded(
                  child: _FadeSlideIn(
                    child: _StatCard(
                      label: '총 집중 시간',
                      value: formatMinutes(report.totalMinutes),
                      color: const Color(0xFFF6E1DF),
                      barColor: const Color(0xFFE06B63),
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _StatCard(
                      label: '완료 할일',
                      value: '${report.completedTodos}개',
                      color: const Color(0xFFDCF0CE),
                      barColor: const Color(0xFF79B13D),
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _StatCard(
                      label: '평균 집중도',
                      value: report.avgFocus != null
                          ? '${report.avgFocus!.toStringAsFixed(0)}%'
                          : '-',
                      color: const Color(0xFFDCE8F7),
                      barColor: const Color(0xFF7B89FF),
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
            loading: () => Row(
              children: List.generate(
                  3,
                  (_) => Expanded(
                        child: Container(
                          height: 64,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFEEEEEE), // ✅
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )),
            ),
            error: (_, __) => const SizedBox(),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              // ── 첫 번째: 시간별 집중도 + 모드 비율 ──
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 시간별 집중도
                    _FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white, // ✅
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: hourlyBuckets.when(
                          data: (buckets) {
                            final subjects = {
                              for (final b in buckets)
                                b.subjectId: (
                                  b.subjectName,
                                  Color(b.subjectColor)
                                )
                            };
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '시간별 집중도',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF222222), // ✅
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_selectedDate.month}/${_selectedDate.day}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9E9E9E)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                buckets.isEmpty
                                    ? SizedBox(
                                        height: 100,
                                        child: Center(
                                          child: Text(
                                            '학습 기록이 없어요',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? const Color(0xFF666666)
                                                  : const Color(
                                                      0xFFBBBBBB), // ✅
                                            ),
                                          ),
                                        ),
                                      )
                                    : _HourlyBarChart(buckets: buckets),
                                if (subjects.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: subjects.entries
                                        .map(
                                          (e) => _LegendDot(
                                              color: e.value.$2,
                                              label: e.value.$1),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            );
                          },
                          loading: () => const SizedBox(
                              height: 120,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                          error: (_, __) => const SizedBox(height: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 모드 비율 (시험 vs 학습)
                    _FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white, // ✅
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: modeRatio.when(
                          data: (ratio) => Column(
                            children: [
                              _AnimatedValueText(
                                value: formatMinutes(ratio.totalMinutes),
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF222222),
                                ),
                              ),
                              Text(
                                '총 공부 시간',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF9E9E9E), // ✅
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: 200,
                                height: 110,
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                      '${ratio.studyRatio}|${ratio.examRatio}'),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, t, child) {
                                    return CustomPaint(
                                      painter: _SemiDonutPainter(
                                        studyRatio: ratio.studyRatio * t,
                                        examRatio: ratio.examRatio * t,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _LegendDot(
                                              color: Color(0xFF97D778),
                                              label: '학습'),
                                          SizedBox(width: 10),
                                          _LegendDot(
                                              color: Color(0xFFF0C06F),
                                              label: '시험'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '학습 ${(ratio.studyRatio * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9E9E9E),
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '시험 ${(ratio.examRatio * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9E9E9E),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          loading: () => const SizedBox(
                              height: 160,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                          error: (_, __) => const SizedBox(height: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI 학습 인사이트
                    if ((dailyReport.valueOrNull?.totalMinutes ?? 0) > 0)
                      _FadeSlideIn(
                        delay: const Duration(milliseconds: 380),
                        child: _buildDailyInsightCard(
                          isDark,
                          dailyReport.value!,
                          hourlyBuckets.value ?? [],
                          activities.value ?? [],
                          modeRatio.value ?? ModeRatio.empty,
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── 두 번째: Activity 목록 ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // ✅
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: activities.when(
                    data: (list) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF222222), // ✅
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.month}월 ${_selectedDate.day}일',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        list.isEmpty
                            ? Expanded(
                                child: Center(
                                  child: Text(
                                    '학습 기록이 없어요',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFF666666)
                                          : const Color(0xFFBBBBBB), // ✅
                                    ),
                                  ),
                                ),
                              )
                            : Expanded(
                                child: ListView.builder(
                                  itemCount: list.length,
                                  itemBuilder: (context, i) => _FadeSlideIn(
                                    delay: Duration(
                                        milliseconds: 60 * i.clamp(0, 8)),
                                    child: _ActivityItem(
                                      entry: list[i],
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 페이지 인디케이터
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              final active = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFD97068)
                      : const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 주간 탭
// ─────────────────────────────────────────────────────────
class _WeeklyTab extends ConsumerStatefulWidget {
  final bool isDark; // ✅

  const _WeeklyTab({required this.isDark}); // ✅

  @override
  ConsumerState<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends ConsumerState<_WeeklyTab> {
  int? _selectedDayIndex;
  DateTime _weekStart = _getWeekStart(DateTime.now());
  String? _insightText;
  bool _insightLoading = false;

  static DateTime _getWeekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  void _changeWeek(int delta) {
    final next = _weekStart.add(Duration(days: delta * 7));
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _weekStart = next;
      _selectedDayIndex = null;
      _insightText = null;
      _insightLoading = false;
    });
  }

  Future<void> _generateWeeklyInsight(WeeklyReport report) async {
    if (_insightLoading) return;
    setState(() {
      _insightLoading = true;
      _insightText = null;
    });
    final end = _weekStart.add(const Duration(days: 6));
    final period =
        '${_weekStart.month}/${_weekStart.day} - ${end.month}/${end.day}';
    const weekdays = ['', '월', '화', '수', '목', '금', '토', '일'];
    final bestDay = report.maxFocusDay != null
        ? '${report.maxFocusDay!.month}/${report.maxFocusDay!.day}(${weekdays[report.maxFocusDay!.weekday]})'
        : '-';
    final subjectMinMap = <String, int>{};
    final subjectNameMap = <String, String>{};
    for (final b in report.buckets) {
      subjectMinMap[b.subjectId] =
          (subjectMinMap[b.subjectId] ?? 0) + b.minutes;
      subjectNameMap[b.subjectId] = b.subjectName;
    }
    String mostStudied = '-';
    if (subjectMinMap.isNotEmpty) {
      final maxId =
          subjectMinMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      mostStudied = subjectNameMap[maxId] ?? '-';
    }
    final prompt = SlmPrompts.reportInsight(
      period: '이번 주 ($period)',
      totalStudyTime: formatMinutesKo(report.totalMinutes),
      completedTodos: report.completedTodos,
      averageFocusPercent: report.maxFocusValue?.toInt() ?? 0,
      totalSessions: report.buckets.length,
      bestFocusTimeSlot: bestDay,
      weakFocusTimeSlot: '-',
      mostStudiedSubject: mostStudied,
      lowestFocusSubject: '-',
      studyModeRatio: '-',
    );
    try {
      final slm = ref.read(slmServiceProvider);
      await slm.load();
      await slm.resetSession();
      final buf = StringBuffer();
      final uiUpdateClock = Stopwatch()..start();
      await for (final token in slm.generate(prompt)) {
        buf.write(token);
        if (mounted && uiUpdateClock.elapsed >= _kInsightUiUpdateInterval) {
          uiUpdateClock.reset();
          setState(() => _insightText = buf.toString());
        }
      }
      if (mounted) setState(() => _insightText = buf.toString());
    } catch (e) {
      if (mounted) setState(() => _insightText = SlmPrompts.fallbackCoaching);
    } finally {
      if (mounted) setState(() => _insightLoading = false);
    }
  }

  Widget _buildWeeklyInsightCard(bool isDark, WeeklyReport report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B89FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('AI',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7B89FF))),
              ),
              const SizedBox(width: 8),
              Text(
                '주간 학습 인사이트',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_insightText != null)
            Text(
              _insightText!,
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFFCCCCCC) : const Color(0xFF444444),
                height: 1.6,
              ),
            )
          else if (_insightLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!Platform.isIOS && !Platform.isAndroid)
            Text(
              'iOS/Android에서만 지원됩니다.',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF666666) : Colors.grey),
            )
          else
            GestureDetector(
              onTap: () => _generateWeeklyInsight(report),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B89FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '인사이트 생성',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_weekStart.month}/${_weekStart.day} - ${end.month}/${end.day}';
  }

  String _dayLabel(DateTime d) {
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} (${weekdays[d.weekday]})';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark; // ✅
    final weeklyAsync = ref.watch(weeklyReportProvider(_weekStart));

    return weeklyAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(child: Text('데이터를 불러올 수 없어요')),
      data: (report) {
        // 7일치 데이터 준비 (데이터 없는 날도 포함)
        final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

        // (day → subjectId → minutes)
        final dayMap = <DateTime, Map<String, _SubjectMin>>{};
        for (final b in report.buckets) {
          dayMap.putIfAbsent(b.day, () => {});
          dayMap[b.day]![b.subjectId] = _SubjectMin(
            name: b.subjectName,
            color: Color(b.subjectColor),
            minutes: b.minutes,
          );
        }

        // 전체 과목 색상 범례
        final allSubjects = <String, _SubjectMin>{};
        for (final b in report.buckets) {
          allSubjects.putIfAbsent(
              b.subjectId,
              () => _SubjectMin(
                    name: b.subjectName,
                    color: Color(b.subjectColor),
                    minutes: 0,
                  ));
          allSubjects[b.subjectId]!.minutes += b.minutes;
        }
        final sortedSubjects = allSubjects.values.toList()
          ..sort((a, b) => b.minutes.compareTo(a.minutes));

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // 주 네비게이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PressableScale(
                        onTap: () => _changeWeek(-1),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left,
                              color: Color(0xFFAAAAAA)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AnimatedValueText(
                        value: _weekLabel(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PressableScale(
                        onTap: () => _changeWeek(1),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.chevron_right,
                            color: _weekStart
                                    .add(const Duration(days: 7))
                                    .isAfter(DateTime.now())
                                ? const Color(0xFFDDDDDD)
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 통계 카드 3종
                  Row(
                    children: [
                      Expanded(
                        child: _FadeSlideIn(
                          child: _StatCard(
                            label: '총 집중 시간',
                            value: formatMinutes(report.totalMinutes),
                            color: const Color(0xFFF6E1DF),
                            barColor: const Color(0xFFE06B63),
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          child: _StatCard(
                            label: '완료 할일',
                            value: '${report.completedTodos}개',
                            color: const Color(0xFFDCF0CE),
                            barColor: const Color(0xFF79B13D),
                            isDark: isDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FadeSlideIn(
                          delay: const Duration(milliseconds: 160),
                          child: _StatCard(
                            label: '최고 집중일',
                            value: report.maxFocusDay != null
                                ? '${report.maxFocusDay!.month}/${report.maxFocusDay!.day}'
                                : '-',
                            color: const Color(0xFFDCE8F7),
                            barColor: const Color(0xFF7B89FF),
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 일별 집중도 바
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 220),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '일별 집중도',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF222222), // ✅
                                ),
                              ),
                              const Spacer(),
                              Text(_weekLabel(),
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF9E9E9E))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...days.asMap().entries.map((entry) {
                            final index = entry.key;
                            final day = entry.value;
                            final subjects = dayMap[day] ?? {};
                            final total = subjects.values
                                .fold(0, (s, v) => s + v.minutes);
                            final isSelected = _selectedDayIndex == index;

                            return GestureDetector(
                              onTap: () => setState(() {
                                _selectedDayIndex =
                                    _selectedDayIndex == index ? null : index;
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? isDark
                                          ? const Color(0xFF3D2B2A) // ✅
                                          : const Color(0xFFFFF5F5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color(0xFFF1B0A9))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 94,
                                      child: Text(
                                        _dayLabel(day),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? const Color(0xFFE06B63)
                                              : isDark
                                                  ? const Color(0xFFAAAAAA) // ✅
                                                  : const Color(0xFF666666),
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: total == 0
                                          ? Container(
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF3A3A3A)
                                                    : const Color(0xFFF0F0F0),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            )
                                          : TweenAnimationBuilder<double>(
                                              key: ValueKey(
                                                  '$index|${subjects.entries.map((e) => '${e.key}:${e.value.minutes}').join(',')}'),
                                              tween:
                                                  Tween(begin: 0.0, end: 1.0),
                                              duration: Duration(
                                                  milliseconds:
                                                      600 + index * 80),
                                              curve: Curves.easeOutCubic,
                                              builder: (context, t, _) {
                                                return Stack(
                                                  children: [
                                                    Container(
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF2A2A2A)
                                                            : const Color(
                                                                0xFFF5F5F5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                    ),
                                                    FractionallySizedBox(
                                                      widthFactor: t,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        child: SizedBox(
                                                          height: 14,
                                                          child: Row(
                                                            children: subjects
                                                                .entries
                                                                .map((e) {
                                                              return Flexible(
                                                                flex: e.value
                                                                    .minutes,
                                                                child: Container(
                                                                    color: e
                                                                        .value
                                                                        .color),
                                                              );
                                                            }).toList(),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        total > 0 ? formatMinutes(total) : '',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? const Color(0xFF888888)
                                              : const Color(0xFF999999), // ✅
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (sortedSubjects.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: sortedSubjects
                                  .take(5)
                                  .map(
                                    (s) => _LegendDot(
                                        color: s.color, label: s.name),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 과목별 도넛 차트
                  _FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '과목별 비중',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF222222), // ✅
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (sortedSubjects.isEmpty)
                            SizedBox(
                              height: 100,
                              child: Center(
                                child: Text(
                                  '학습 기록이 없어요',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF666666)
                                        : const Color(0xFFBBBBBB), // ✅
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            SizedBox(
                              width: 160,
                              height: 160,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    key: ValueKey(sortedSubjects
                                        .map((s) => '${s.name}:${s.minutes}')
                                        .join(',')),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, t, _) {
                                      return CustomPaint(
                                        size: const Size(160, 160),
                                        painter: _DonutChartPainter(
                                          segments: sortedSubjects
                                              .map(
                                                (s) => _DonutSegment(
                                                    color: s.color,
                                                    value:
                                                        s.minutes.toDouble()),
                                              )
                                              .toList(),
                                          progress: t,
                                        ),
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _AnimatedValueText(
                                        value:
                                            formatMinutes(report.totalMinutes),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF222222),
                                        ),
                                      ),
                                      Text(
                                        '총 공부 시간',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? const Color(0xFF888888)
                                              : const Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...sortedSubjects
                                .take(5)
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                              final i = entry.key;
                              final s = entry.value;
                              return _FadeSlideIn(
                                delay: Duration(milliseconds: 400 + i * 70),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                              color: s.color,
                                              shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? const Color(0xFFAAAAAA)
                                                : const Color(0xFF444444),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formatMinutes(s.minutes),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF333333),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (report.totalMinutes > 0) ...[
                    _FadeSlideIn(
                      delay: const Duration(milliseconds: 380),
                      child: _buildWeeklyInsightCard(isDark, report),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // 날짜별 과목 팝업
            if (_selectedDayIndex != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // ✅
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _dayLabel(days[_selectedDayIndex!]),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF222222), // ✅
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDayIndex = null),
                            child: const Icon(Icons.close,
                                size: 18, color: Color(0xFFAAAAAA)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...() {
                        final subjects = dayMap[days[_selectedDayIndex!]] ?? {};
                        if (subjects.isEmpty) {
                          return [
                            Center(
                              child: Text(
                                '학습 기록이 없어요',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF666666)
                                      : const Color(0xFFBBBBBB), // ✅
                                ),
                              ),
                            ),
                          ];
                        }
                        final total =
                            subjects.values.fold(0, (s, v) => s + v.minutes);
                        return subjects.entries
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            e.value.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? const Color(0xFFAAAAAA)
                                                  : const Color(
                                                      0xFF444444), // ✅
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            formatMinutes(e.value.minutes),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(
                                                      0xFF333333), // ✅
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: total > 0
                                              ? e.value.minutes / total
                                              : 0,
                                          backgroundColor: isDark
                                              ? const Color(0xFF3A3A3A)
                                              : const Color(0xFFEEEEEE), // ✅
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  e.value.color),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList();
                      }(),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// 주간 과목 집계용 내부 모델
class _SubjectMin {
  final String name;
  final Color color;
  int minutes;
  _SubjectMin({required this.name, required this.color, required this.minutes});
}

// ─────────────────────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color barColor;
  final bool isDark; // ✅

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.barColor,
    required this.isDark, // ✅
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.3) : color, // ✅
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                  color: barColor, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark
                  ? const Color(0xFF888888)
                  : const Color(0xFF666666), // ✅
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _AnimatedValueText(
            value: value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final ActivityEntry entry;
  final bool isDark; // ✅

  const _ActivityItem({
    required this.entry,
    required this.isDark, // ✅
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${entry.startedAt.hour.toString().padLeft(2, '0')}:${entry.startedAt.minute.toString().padLeft(2, '0')}';
    final focusStr = entry.focusScore != null
        ? '집중도 ${(entry.focusScore! * 100).toStringAsFixed(0)}%'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF333333), // ✅
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                  color: Color(entry.subjectColor),
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.subjectName,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  entry.goalTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF333333), // ✅
                  ),
                ),
                if (focusStr.isNotEmpty)
                  Text(focusStr,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
          if (entry.durationMinutes != null)
            Text(
              formatMinutes(entry.durationMinutes!),
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
      ],
    );
  }
}

// 시간별 집중도 바 차트 — 실제 HourlyBucket 데이터 사용
class _HourlyBarChart extends StatelessWidget {
  final List<HourlyBucket> buckets;
  const _HourlyBarChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    // 시간별 집계: hour → subjectId → minutes
    final hourMap = <int, Map<String, HourlyBucket>>{};
    for (final b in buckets) {
      hourMap.putIfAbsent(b.hour, () => <String, HourlyBucket>{})[b.subjectId] =
          b;
    }

    final hours = hourMap.keys.toList()..sort();
    final maxTotal = hours.fold<int>(0, (max, h) {
      final total = hourMap[h]!.values.fold(0, (s, b) => s + b.minutes);
      return total > max ? total : max;
    });

    if (hours.isEmpty || maxTotal == 0) return const SizedBox(height: 100);

    // 데이터 변경 시 바가 0 → 실제 높이로 자라남.
    // ValueKey 로 buckets 식별 → 데이터 바뀌면 트윈이 다시 시작.
    return TweenAnimationBuilder<double>(
      key: ValueKey(buckets
          .map((b) => '${b.hour}|${b.subjectId}|${b.minutes}')
          .join(',')),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: ['75%', '50%', '25%']
                    .map(
                      (l) => Text(l,
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFFBBBBBB))),
                    )
                    .toList(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: hours.map((hour) {
                    final subjects = hourMap[hour]!;
                    final total =
                        subjects.values.fold(0, (s, b) => s + b.minutes);
                    final fullHeight = (total / maxTotal) * 120;
                    final barHeight = fullHeight * t;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                          child: SizedBox(
                            width: 10,
                            height: barHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: subjects.values.map((b) {
                                return Flexible(
                                  flex: b.minutes,
                                  child:
                                      Container(color: Color(b.subjectColor)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${hour.toString().padLeft(2, '0')}시',
                          style: const TextStyle(
                              fontSize: 8, color: Color(0xFFBBBBBB)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SemiDonutPainter extends CustomPainter {
  final double studyRatio;
  final double examRatio;
  const _SemiDonutPainter({required this.studyRatio, required this.examRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 10;
    const strokeWidth = 22.0;

    // 배경
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFEEEEEE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // 학습 비율 (초록)
    if (studyRatio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * studyRatio,
        false,
        Paint()
          ..color = const Color(0xFF97D778)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // 시험 비율 (노랑)
    if (examRatio > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi + math.pi * studyRatio,
        math.pi * examRatio,
        false,
        Paint()
          ..color = const Color(0xFFF0C06F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SemiDonutPainter old) =>
      old.studyRatio != studyRatio || old.examRatio != examRatio;
}

class _DonutSegment {
  final Color color;
  final double value;
  _DonutSegment({required this.color, required this.value});
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double progress; // 0..1, sweep 비율
  _DonutChartPainter({required this.segments, this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 28.0;
    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.02,
        false,
        Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) =>
      old.progress != progress || old.segments != segments;
}
