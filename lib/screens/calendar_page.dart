import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/study_goal.dart';
import '../providers/calendar_provider.dart';
import 'camera_page.dart';
import 'main_screen.dart';
import 'subject_page.dart';
import 'report_page.dart';

class CalendarPageShell extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;

  const CalendarPageShell({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
    required this.nickname,
    this.profileImagePath,
  });

  @override
  ConsumerState<CalendarPageShell> createState() => _CalendarPageShellState();
}

class _CalendarPageShellState extends ConsumerState<CalendarPageShell> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    });
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraPage(
          initialSelectedTask: null,
          allTasks: [],
        ),
      ),
    );
  }

  List<DateTime?> _buildMonthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final firstWeekday = firstDay.weekday;
    final totalDays = lastDay.day;

    final result = <DateTime?>[];
    for (int i = 1; i < firstWeekday; i++) {
      result.add(null);
    }
    for (int day = 1; day <= totalDays; day++) {
      result.add(DateTime(month.year, month.month, day));
    }
    while (result.length % 7 != 0) {
      result.add(null);
    }
    return result;
  }

  List<Widget> _reviewDotsRow(List<CalendarReviewEntry> reviews) {
    if (reviews.isEmpty) return const [];

    final visible = reviews.take(4).toList();
    final extra = reviews.length - visible.length;

    final children = <Widget>[];
    for (int i = 0; i < visible.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 3));
      children.add(Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: visible[i].subjectColor,
          shape: BoxShape.circle,
        ),
      ));
    }
    if (extra > 0) {
      children.add(const SizedBox(width: 2));
      children.add(Text(
        '+$extra',
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9A9A9A),
          height: 1,
        ),
      ));
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthTitle(DateTime d) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month]} ${d.year}';
  }

  void _openDetail(
    DateTime day,
    CalendarMonthData data,
  ) {
    setState(() => _selectedDate = day);
    final stats = data.focusByDay[_key(day)] ?? DayFocusStats.empty;
    final reviews = data.reviewsByDay[_key(day)] ?? const <CalendarReviewEntry>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarDetailPage(
          selectedDate: day,
          focusStats: stats,
          reviews: reviews,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildMonthDays(_focusedMonth);
    final monthAsync = ref.watch(calendarMonthDataProvider(_focusedMonth));
    final data = monthAsync.valueOrNull ?? CalendarMonthData.empty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _changeMonth(-1),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xFFF1F1F1),
                                    child: Icon(
                                      Icons.chevron_left,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Text(
                                  _monthTitle(_focusedMonth),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _changeMonth(1),
                                  child: const CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xFFF1F1F1),
                                    child: Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _WeekText('MON'),
                                _WeekText('TUE'),
                                _WeekText('WED'),
                                _WeekText('THU'),
                                _WeekText('FRI'),
                                _WeekText('SAT', color: Color(0xFF7EA3FF)),
                                _WeekText('SUN', color: Color(0xFFF08AA1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: days.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 0.85,
                              ),
                              itemBuilder: (context, index) {
                                final day = days[index];
                                if (day == null) return const SizedBox();

                                final isSelected =
                                    _isSameDay(day, _selectedDate);
                                final key = _key(day);
                                final stats = data.focusByDay[key];
                                final reviews =
                                    data.reviewsByDay[key] ?? const [];

                                return GestureDetector(
                                  onTap: () => _openDetail(day, data),
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFF9F4F4)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: day.weekday == DateTime.sunday
                                                ? const Color(0xFFF08AA1)
                                                : day.weekday ==
                                                        DateTime.saturday
                                                    ? const Color(0xFF7EA3FF)
                                                    : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (stats != null && stats.sessionCount > 0)
                                          _TomatoFace(level: stats.level)
                                        else
                                          const SizedBox(height: 22),
                                        ..._reviewDotsRow(reviews),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                CalendarBottomNavBar(
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

class CalendarDetailPage extends StatefulWidget {
  final DateTime selectedDate;
  final DayFocusStats focusStats;
  final List<CalendarReviewEntry> reviews;

  const CalendarDetailPage({
    super.key,
    required this.selectedDate,
    required this.focusStats,
    required this.reviews,
  });

  @override
  State<CalendarDetailPage> createState() => _CalendarDetailPageState();
}

class _CalendarDetailPageState extends State<CalendarDetailPage> {
  double _dragOffset = 0;

  String _weekdayKorean(int weekday) {
    const names = ['', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return weekday >= 1 && weekday <= 7 ? names[weekday] : '';
  }

  String _understandingLabel(UnderstandingLevel l) => switch (l) {
        UnderstandingLevel.hard => '어려움',
        UnderstandingLevel.normal => '보통',
        UnderstandingLevel.easy => '쉬움',
      };

  String _lastReviewLabel(DateTime? lastReview) {
    if (lastReview == null) return '첫 학습';
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final l = DateTime(lastReview.year, lastReview.month, lastReview.day);
    final diff = t.difference(l).inDays;
    if (diff <= 0) return '오늘 복습';
    return '마지막 복습 $diff일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.delta.dy > 0) {
              setState(() => _dragOffset += details.delta.dy);
            }
          },
          onVerticalDragEnd: (_) {
            if (_dragOffset > 120) {
              Navigator.pop(context);
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _dragOffset, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '${widget.selectedDate.month}월 ${widget.selectedDate.day}일 ${_weekdayKorean(widget.selectedDate.weekday)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (widget.focusStats.sessionCount > 0)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: _FocusSummaryCard(stats: widget.focusStats),
                          ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.reviews.isEmpty
                                ? '복습 일정 없음'
                                : '복습 (${widget.reviews.length}건)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: widget.reviews.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 40),
                                    child: Text(
                                      '오늘은 복습할 일정이 없어요',
                                      style: TextStyle(
                                        color: Color(0xFFB3B3B3),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 16),
                                  itemCount: widget.reviews.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final r = widget.reviews[index];
                                    return _ReviewCard(
                                      entry: r,
                                      understandingLabel:
                                          _understandingLabel(
                                              r.understandingLevel),
                                      lastReviewLabel:
                                          _lastReviewLabel(r.lastReview),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusSummaryCard extends StatelessWidget {
  final DayFocusStats stats;
  const _FocusSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final percent = (stats.avgFocusScore * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF6F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: stats.avgFocusScore.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: const Color(0xFFF0DDD8),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD97068),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97068),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '집중도',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                    label: '총 학습 시간',
                    value: _formatDuration(stats.totalDurationMinutes)),
                const SizedBox(height: 6),
                _StatRow(
                  label: '완료 세션',
                  value: '${stats.sessionCount}회',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF232323),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final CalendarReviewEntry entry;
  final String understandingLabel;
  final String lastReviewLabel;

  const _ReviewCard({
    required this.entry,
    required this.understandingLabel,
    required this.lastReviewLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: entry.subjectColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.subjectName} · ${entry.goalTitle}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF232323),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '이해도 $understandingLabel · $lastReviewLabel',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ReviewBadge(overdueDays: entry.overdueDays),
        ],
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  final int overdueDays;
  const _ReviewBadge({required this.overdueDays});

  @override
  Widget build(BuildContext context) {
    final urgent = overdueDays > 0;
    final label = urgent ? '$overdueDays일 밀림' : '오늘';
    final bg = urgent ? const Color(0xFFFFD9D5) : const Color(0xFFFFEFEC);
    final fg = urgent ? const Color(0xFFB83C32) : const Color(0xFFD97068);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _WeekText extends StatelessWidget {
  final String text;
  final Color color;

  const _WeekText(this.text, {this.color = const Color(0xFFB7B7B7)});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TomatoFace extends StatelessWidget {
  final DayFocusLevel level;

  const _TomatoFace({required this.level});

  @override
  Widget build(BuildContext context) {
    final imagePath = switch (level) {
      DayFocusLevel.high => 'assets/images/twemoji_tomato-1.png',
      DayFocusLevel.medium => 'assets/images/twemoji_tomato-2.png',
      DayFocusLevel.low => 'assets/images/twemoji_tomato.png',
      DayFocusLevel.none => 'assets/images/twemoji_tomato-3.png',
    };
    return SizedBox(
      width: 22,
      height: 22,
      child: Image.asset(imagePath, fit: BoxFit.contain),
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

class CalendarBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;
  final VoidCallback onTapTomato;

  const CalendarBottomNavBar({
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
        border: Border(
          top: BorderSide(color: Color(0xFFE9E9E9), width: 1),
        ),
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
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => MainScreen(
                    nickname: nickname,
                    profileImagePath: profileImagePath,
                    currentIndex: 0,
                    onTapNav: onTapNav,
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
                (route) => false,
              );
            },
          ),
          _BottomNavIcon(
            icon: Icons.calendar_month,
            label: 'Calendar',
            active: true,
            onTap: () {},
          ),
          _BottomTomatoItem(onTap: onTapTomato),
          _BottomNavIcon(
            icon: Icons.bar_chart,
            label: 'Report',
            active: false,
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => ReportPageShell(
                    currentIndex: 3,
                    onTapNav: onTapNav,
                    nickname: nickname,
                    profileImagePath: profileImagePath,
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
          _BottomNavIcon(
            icon: Icons.book,
            label: 'Subject',
            active: false,
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SubjectPageShell(
                    currentIndex: 2,
                    onTapNav: onTapNav,
                    nickname: nickname,
                    profileImagePath: profileImagePath,
                  ),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BottomTomatoItem extends StatelessWidget {
  final VoidCallback onTap;

  const _BottomTomatoItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
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
