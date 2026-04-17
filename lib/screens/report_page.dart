import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'main_screen.dart';
import 'calendar_page.dart';
import 'subject_page.dart';
import 'my_page.dart';

class ReportPageShell extends StatefulWidget {
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
  State<ReportPageShell> createState() => _ReportPageShellState();
}

class _ReportPageShellState extends State<ReportPageShell>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.black,
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
                    children: const [
                      _DailyTab(),
                      _WeeklyTab(),
                    ],
                  ),
                ),
                _ReportBottomNavBar(
                  currentIndex: widget.currentIndex,
                  onTapNav: widget.onTapNav,
                  nickname: widget.nickname,
                  profileImagePath: widget.profileImagePath,
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
// 첫 페이지: 시간별 집중도 + 총 공부시간
// 두 번째 페이지: Activity 목록
// ─────────────────────────────────────────────────────────
class _DailyTab extends StatefulWidget {
  const _DailyTab();

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _todayActivities = [
    {'time': '13:10', 'subject': '알고리즘', 'color': Color(0xFFF08AA1), 'task': '1. 회귀 분석'},
    {'time': '17:15', 'subject': '데이터 베이스', 'color': Color(0xFF97D778), 'task': '1. sqld 정의, 개념'},
    {'time': '21:30', 'subject': '데이터 통신', 'color': Color(0xFF90C4FF), 'task': '2. 네트워크 모델'},
  ];

  final List<Map<String, dynamic>> _pastActivities = [
    {'time': '09:00', 'subject': '캡스톤 디자인', 'color': Color(0xFFF0C06F), 'task': '주제 선정 및 간트 차트 작성'},
    {'time': '11:30', 'subject': 'POSITION DESIGNER', 'color': Color(0xFF9F88FF), 'task': 'SkillSwap Session'},
    {'time': '3:30', 'subject': '데이터 통신', 'color': Color(0xFF90C4FF), 'task': '2. 네트워크 모델'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 통계 카드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _StatCard(label: '총 집중 시간', value: '3h 30m', color: const Color(0xFFF6E1DF), barColor: const Color(0xFFE06B63))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: '완료 과목', value: '2개', color: const Color(0xFFDCF0CE), barColor: const Color(0xFF79B13D))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: '평균 집중도', value: '1h 30m', color: const Color(0xFFDCE8F7), barColor: const Color(0xFF7B89FF))),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              // ── 첫 번째: 시간별 집중도 + 총 공부시간 ──
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Text('시간별 집중도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                              Spacer(),
                              Text('Apr, 01 - 07', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _HourlyBarChart(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              _LegendDot(color: Color(0xFFF08AA1), label: '데이터베이스'),
                              SizedBox(width: 12),
                              _LegendDot(color: Color(0xFF90C4FF), label: '데이터통신'),
                              SizedBox(width: 12),
                              _LegendDot(color: Color(0xFF97D778), label: '알고리즘'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        children: [
                          const Text('1342', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF222222))),
                          const Text('총 공부 시간', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 200,
                            height: 110,
                            child: CustomPaint(
                              painter: _SemiDonutPainter(),
                              child: const Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LegendDot(color: Color(0xFF97D778), label: 'Full Time'),
                                      SizedBox(width: 10),
                                      _LegendDot(color: Color(0xFFF0C06F), label: 'Part Time'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('33%', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
                              Text('67', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                      const SizedBox(height: 4),
                      const Text('TODAY', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          children: [
                            ..._todayActivities.map((item) => _ActivityItem(item: item)),
                            const SizedBox(height: 8),
                            const Text('AUGUST 24, 2023', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            const SizedBox(height: 10),
                            ..._pastActivities.map((item) => _ActivityItem(item: item)),
                          ],
                        ),
                      ),
                    ],
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
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index ? const Color(0xFFE06B63) : const Color(0xFFD9D9D9),
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
// 주간 탭 — 날짜 탭하면 그 날의 과목 데이터로 팝업
// ─────────────────────────────────────────────────────────
class _WeeklyTab extends StatefulWidget {
  const _WeeklyTab();

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  int? _selectedDayIndex;

  final List<Map<String, dynamic>> _weekData = [
    {
      'day': '04/01 (Mon)',
      'bars': [
        {'color': Color(0xFFF08AA1), 'ratio': 0.5},
        {'color': Color(0xFF90C4FF), 'ratio': 0.3},
        {'color': Color(0xFFF0C06F), 'ratio': 0.2},
      ],
      'subjects': [
        {'name': '알고리즘', 'percent': 50, 'color': Color(0xFFF08AA1)},
        {'name': '데이터 통신', 'percent': 30, 'color': Color(0xFF90C4FF)},
        {'name': '캡스톤 디자인', 'percent': 20, 'color': Color(0xFFF0C06F)},
      ],
    },
    {
      'day': '04/02 (Tue)',
      'bars': [
        {'color': Color(0xFF9F88FF), 'ratio': 0.6},
        {'color': Color(0xFF97D778), 'ratio': 0.25},
        {'color': Color(0xFFF08AA1), 'ratio': 0.15},
      ],
      'subjects': [
        {'name': '데이터베이스', 'percent': 60, 'color': Color(0xFF9F88FF)},
        {'name': '알고리즘', 'percent': 25, 'color': Color(0xFF97D778)},
        {'name': '운영체제', 'percent': 15, 'color': Color(0xFFF08AA1)},
      ],
    },
    {
      'day': '04/03 (Wed)',
      'bars': [
        {'color': Color(0xFF90C4FF), 'ratio': 0.55},
        {'color': Color(0xFFF0C06F), 'ratio': 0.45},
      ],
      'subjects': [
        {'name': '데이터 통신', 'percent': 55, 'color': Color(0xFF90C4FF)},
        {'name': '캡스톤 디자인', 'percent': 45, 'color': Color(0xFFF0C06F)},
      ],
    },
    {
      'day': '04/04 (Thu)',
      'bars': [
        {'color': Color(0xFF97D778), 'ratio': 0.55},
        {'color': Color(0xFF9F88FF), 'ratio': 0.25},
        {'color': Color(0xFFF08AA1), 'ratio': 0.20},
      ],
      'subjects': [
        {'name': '알고리즘', 'percent': 55, 'color': Color(0xFF97D778)},
        {'name': '데이터베이스', 'percent': 25, 'color': Color(0xFF9F88FF)},
        {'name': '운영체제', 'percent': 20, 'color': Color(0xFFF08AA1)},
      ],
    },
    {
      'day': '04/05 (Fri)',
      'bars': [
        {'color': Color(0xFFF08AA1), 'ratio': 0.45},
        {'color': Color(0xFF90C4FF), 'ratio': 0.55},
      ],
      'subjects': [
        {'name': '알고리즘', 'percent': 45, 'color': Color(0xFFF08AA1)},
        {'name': '데이터 통신', 'percent': 55, 'color': Color(0xFF90C4FF)},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(label: '총 집중 시간', value: '-h -m', color: const Color(0xFFF6E1DF), barColor: const Color(0xFFE06B63))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: '완료 과목', value: '-개', color: const Color(0xFFDCF0CE), barColor: const Color(0xFF79B13D))),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: '최고 집중일', value: '-/-', color: const Color(0xFFDCE8F7), barColor: const Color(0xFF7B89FF))),
                ],
              ),
              const SizedBox(height: 16),

              // 일별 집중도
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('일별 집중도', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                        Spacer(),
                        Text('Apr, 01 - 07', style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(_weekData.length, (index) {
                      final dayData = _weekData[index];
                      final bars = dayData['bars'] as List<Map<String, dynamic>>;
                      final isSelected = _selectedDayIndex == index;

                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDayIndex = _selectedDayIndex == index ? null : index;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFF5F5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected ? Border.all(color: const Color(0xFFF1B0A9), width: 1) : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 88,
                                child: Text(
                                  dayData['day'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? const Color(0xFFE06B63) : const Color(0xFF666666),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    height: 14,
                                    child: Row(
                                      children: bars.map((bar) {
                                        return Flexible(
                                          flex: ((bar['ratio'] as double) * 100).round(),
                                          child: Container(color: bar['color'] as Color),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        _LegendDot(color: Color(0xFFF08AA1), label: '알고리즘'),
                        SizedBox(width: 12),
                        _LegendDot(color: Color(0xFF90C4FF), label: '데이터 통신'),
                        SizedBox(width: 12),
                        _LegendDot(color: Color(0xFFF0C06F), label: '캡스톤 디자인'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 도넛 차트
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(160, 160),
                            painter: _DonutChartPainter(segments: [
                              _DonutSegment(color: const Color(0xFF97D778), value: 54),
                              _DonutSegment(color: const Color(0xFF9F88FF), value: 38),
                              _DonutSegment(color: const Color(0xFFF0C06F), value: 8),
                            ]),
                          ),
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('42h', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                              Text('총 공부 시간', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // 과목별 집중 시간 팝업 — 선택된 날짜 데이터 사용
        if (_selectedDayIndex != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('과목별 집중 시간', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = null),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFFAAAAAA)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 선택된 날짜의 subjects 데이터
                  ...(_weekData[_selectedDayIndex!]['subjects'] as List<Map<String, dynamic>>).map((subject) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(subject['name'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF444444), fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text('${subject['percent']}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (subject['percent'] as int) / 100.0,
                              backgroundColor: const Color(0xFFEEEEEE),
                              valueColor: AlwaysStoppedAnimation<Color>(subject['color'] as Color),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color barColor;

  const _StatCard({required this.label, required this.value, required this.color, required this.barColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 20, decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF666666), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 42, child: Text(item['time'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333)))),
          const SizedBox(width: 10),
          Container(width: 3, height: 40, decoration: BoxDecoration(color: item['color'] as Color, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['subject'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(item['task'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
              ],
            ),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
      ],
    );
  }
}

class _HourlyBarChart extends StatelessWidget {
  const _HourlyBarChart();

  @override
  Widget build(BuildContext context) {
    final hours = ['13:00', '15:00', '17:00', '19:00', '21:00', '23:00', '1:00'];
    final data = [
      [0.3, 0.5, 0.0], [0.0, 0.2, 0.4], [0.6, 0.3, 0.0],
      [0.0, 0.0, 0.3], [0.4, 0.5, 0.1], [0.2, 0.0, 0.6], [0.0, 0.3, 0.2],
    ];
    final colors = [const Color(0xFFF08AA1), const Color(0xFF90C4FF), const Color(0xFF97D778)];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: ['75%', '50%', '25%'].map((l) => Text(l, style: const TextStyle(fontSize: 9, color: Color(0xFFBBBBBB)))).toList(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(hours.length, (i) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: List.generate(colors.length, (j) {
                          final val = data[i][j];
                          return Container(
                            width: 10,
                            height: val * 100,
                            margin: const EdgeInsets.only(bottom: 1),
                            decoration: BoxDecoration(
                              color: val > 0 ? colors[j] : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }).reversed.toList(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(hours[i], style: const TextStyle(fontSize: 8, color: Color(0xFFBBBBBB))),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemiDonutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 10;
    const strokeWidth = 22.0;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi, false,
      Paint()..color = const Color(0xFFEEEEEE)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi * 0.67, false,
      Paint()..color = const Color(0xFF97D778)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi + math.pi * 0.67, math.pi * 0.33, false,
      Paint()..color = const Color(0xFFF0C06F)..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_SemiDonutPainter oldDelegate) => false;
}

class _DonutSegment {
  final Color color;
  final double value;
  _DonutSegment({required this.color, required this.value});
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  _DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 28.0;
    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle, sweepAngle - 0.02, false,
        Paint()..color = segment.color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.butt,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────
// 상태바 & 하단 네비게이션
// ─────────────────────────────────────────────────────────

class _ReportBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;

  const _ReportBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapNav,
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
        border: Border(top: BorderSide(color: Color(0xFFE9E9E9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(icon: Icons.home, label: 'Home', active: false, onTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => MainScreen(nickname: nickname, profileImagePath: profileImagePath, currentIndex: 0, onTapNav: onTapNav),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
              (route) => false,
            );
          }),
          _NavIcon(icon: Icons.calendar_month, label: 'Calendar', active: false, onTap: () {
            Navigator.pushReplacement(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => CalendarPageShell(currentIndex: 1, onTapNav: onTapNav, nickname: nickname, profileImagePath: profileImagePath),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ));
          }),
          GestureDetector(
            onTap: () {},
            child: SizedBox(width: 46, height: 46, child: ClipOval(child: Image.asset('assets/images/tomato_glasses.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFFD94C43), child: const Center(child: Text('🍅', style: TextStyle(fontSize: 24))))))),
          ),
          _NavIcon(icon: Icons.bar_chart, label: 'Report', active: true, onTap: () {}),
          _NavIcon(icon: Icons.book, label: 'Subject', active: false, onTap: () {
            Navigator.pushReplacement(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => SubjectPageShell(currentIndex: 2, onTapNav: onTapNav, nickname: nickname, profileImagePath: profileImagePath),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ));
          }),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({required this.icon, required this.label, required this.active, required this.onTap});

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
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}