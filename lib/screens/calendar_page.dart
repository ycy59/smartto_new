import 'package:flutter/material.dart';

class CalendarPageShell extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const CalendarPageShell({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  State<CalendarPageShell> createState() => _CalendarPageShellState();
}

class _CalendarPageShellState extends State<CalendarPageShell> {
  DateTime _focusedMonth = DateTime(2026, 2, 1);
  DateTime _selectedDate = DateTime(2026, 2, 13);

  final Map<String, DayFocusLevel> _focusMap = {
    '2026-02-09': DayFocusLevel.low,
    '2026-02-10': DayFocusLevel.none,
    '2026-02-11': DayFocusLevel.medium,
    '2026-02-13': DayFocusLevel.medium,
    '2026-02-14': DayFocusLevel.high,
    '2026-02-18': DayFocusLevel.medium,
    '2026-02-19': DayFocusLevel.low,
    '2026-02-20': DayFocusLevel.low,
    '2026-02-25': DayFocusLevel.medium,
  };

  final Map<String, List<CalendarPlan>> _plans = {
    '2026-02-13': [
      CalendarPlan(
        time: '오후 5:00\n오후 8:10',
        subject: '알고리즘',
        detail: '1, 2 장',
        color: Color(0xFFE5B45E),
      ),
      CalendarPlan(
        time: '오후 8:40\n오후 10:30',
        subject: '데이터통신',
        detail: '1, 2 장',
        color: Color(0xFFB8DE9D),
      ),
      CalendarPlan(
        time: '오후 11:00\n오전 3:50',
        subject: '캡스톤 디자인',
        detail: 'UI 디자인 토대로 앱 구현',
        color: Color(0xFFF08AA1),
      ),
    ],
  };

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  Future<void> _addPlanDialog() async {
    final timeController = TextEditingController();
    final subjectController = TextEditingController();
    final detailController = TextEditingController();
    Color selectedColor = const Color(0xFFE5B45E);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('계획 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: '시간',
                        hintText: '오후 5:00 ~ 오후 8:10',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: '과목명',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailController,
                      decoration: const InputDecoration(
                        labelText: '세부 내용',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ColorPickDot(
                          color: const Color(0xFFE5B45E),
                          selected: selectedColor == const Color(0xFFE5B45E),
                          onTap: () {
                            setInnerState(() {
                              selectedColor = const Color(0xFFE5B45E);
                            });
                          },
                        ),
                        _ColorPickDot(
                          color: const Color(0xFFB8DE9D),
                          selected: selectedColor == const Color(0xFFB8DE9D),
                          onTap: () {
                            setInnerState(() {
                              selectedColor = const Color(0xFFB8DE9D);
                            });
                          },
                        ),
                        _ColorPickDot(
                          color: const Color(0xFFF08AA1),
                          selected: selectedColor == const Color(0xFFF08AA1),
                          onTap: () {
                            setInnerState(() {
                              selectedColor = const Color(0xFFF08AA1);
                            });
                          },
                        ),
                        _ColorPickDot(
                          color: const Color(0xFF90C4FF),
                          selected: selectedColor == const Color(0xFF90C4FF),
                          onTap: () {
                            setInnerState(() {
                              selectedColor = const Color(0xFF90C4FF);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    if (timeController.text.trim().isEmpty ||
                        subjectController.text.trim().isEmpty) {
                      return;
                    }

                    final key = _key(_selectedDate);
                    final list = _plans[key] ?? [];

                    list.add(
                      CalendarPlan(
                        time: timeController.text.trim(),
                        subject: subjectController.text.trim(),
                        detail: detailController.text.trim(),
                        color: selectedColor,
                      ),
                    );

                    setState(() {
                      _plans[key] = list;
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
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

  List<Widget> _miniPlanBars(DateTime day) {
    final plans = _plans[_key(day)] ?? [];
    return plans.take(3).map((e) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        width: 26,
        height: 4,
        decoration: BoxDecoration(
          color: e.color,
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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

  @override
  Widget build(BuildContext context) {
    final days = _buildMonthDays(_focusedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      bottomNavigationBar: CalendarBottomNavBar(
        currentIndex: widget.currentIndex,
        onTapNav: widget.onTapNav,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                const SizedBox(height: 10),
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
                                childAspectRatio: 0.9,
                              ),
                              itemBuilder: (context, index) {
                                final day = days[index];
                                if (day == null) return const SizedBox();

                                final isSelected =
                                    _isSameDay(day, _selectedDate);
                                final key = _key(day);
                                final focus = _focusMap[key];

                                return GestureDetector(
                                  onTap: () {
                                    _selectDate(day);
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration: const Duration(milliseconds: 180),
                                        pageBuilder: (context, animation, _) =>
                                            CalendarDetailPage(
                                          selectedDate: day,
                                          plans: _plans[_key(day)] ?? [],
                                        ),
                                        transitionsBuilder: (context, animation, _, child) =>
                                            FadeTransition(opacity: animation, child: child),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFF9F4F4)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: day.weekday ==
                                                    DateTime.sunday
                                                ? const Color(0xFFF08AA1)
                                                : day.weekday ==
                                                        DateTime.saturday
                                                    ? const Color(0xFF7EA3FF)
                                                    : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (focus != null)
                                          _TomatoFace(level: focus),
                                        const SizedBox(height: 3),
                                        ..._miniPlanBars(day),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarDetailPage extends StatelessWidget {
  final DateTime selectedDate;
  final List<CalendarPlan> plans;

  const CalendarDetailPage({
    super.key,
    required this.selectedDate,
    required this.plans,
  });

  String _weekdayKorean(int weekday) {
    switch (weekday) {
      case 1:
        return '월요일';
      case 2:
        return '화요일';
      case 3:
        return '수요일';
      case 4:
        return '목요일';
      case 5:
        return '금요일';
      case 6:
        return '토요일';
      case 7:
        return '일요일';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
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
                        '${selectedDate.month}월 ${selectedDate.day}일 ${_weekdayKorean(selectedDate.weekday)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: plans.isEmpty
                          ? const Center(
                              child: Text(
                                '등록된 계획이 없습니다',
                                style: TextStyle(
                                  color: Color(0xFFB3B3B3),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: plans.length,
                              itemBuilder: (context, index) {
                                final plan = plans[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 54,
                                        child: Text(
                                          plan.time,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF4F4F4F),
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: plan.color,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.subject,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              plan.detail,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF7F7F7F),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
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
    Color bodyColor;
    switch (level) {
      case DayFocusLevel.high:
        bodyColor = const Color(0xFFD94C43);
        break;
      case DayFocusLevel.medium:
        bodyColor = const Color(0xFFD79A42);
        break;
      case DayFocusLevel.low:
        bodyColor = const Color(0xFFA8CF63);
        break;
      case DayFocusLevel.none:
        bodyColor = const Color(0xFF5A5A5A);
        break;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bodyColor,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          '🍅',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}

class _ColorPickDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorPickDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.shade400,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class CalendarBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const CalendarBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
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
                  onTapNav(0);
                  Navigator.pop(context);
                },
              ),
              _BottomNavIcon(
                icon: Icons.calendar_month,
                label: 'Calendar',
                active: true,
                onTap: () {},
              ),
              const _BottomTomatoItem(),
              _BottomNavIcon(
                icon: Icons.bar_chart,
                label: 'Report',
                active: false,
                onTap: () {},
              ),
              _BottomNavIcon(
                icon: Icons.book,
                label: 'Subject',
                active: false,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
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

class _BottomTomatoItem extends StatelessWidget {
  const _BottomTomatoItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: ClipOval(
            child: Image.asset(
              'assets/images/tomato_glasses.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFD94C43),
                  child: const Center(
                    child: Text('🍅', style: TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum DayFocusLevel {
  high,
  medium,
  low,
  none,
}

class CalendarPlan {
  final String time;
  final String subject;
  final String detail;
  final Color color;

  CalendarPlan({
    required this.time,
    required this.subject,
    required this.detail,
    required this.color,
  });
}
