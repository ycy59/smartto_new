import 'package:flutter/material.dart';
import 'subject_page.dart';
import 'calendar_page.dart';
import 'pomodoro_timer_screen.dart';

class MainScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      bottomNavigationBar: BottomNavBar(
        currentIndex: currentIndex,
        onTapNav: onTapNav,
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    GreetingCard(nickname: nickname),
                    const SizedBox(height: 16),
                    const WeeklyStatsCard(),
                    const SizedBox(height: 16),
                    const TodayPlanCard(),
                    const SizedBox(height: 10),
                    const PageIndicatorDots(),
                    const SizedBox(height: 14),
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

class GreetingCard extends StatelessWidget {
  final String nickname;

  const GreetingCard({
    super.key,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = nickname.trim().isEmpty ? '이용자' : nickname.trim();

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
            '안녕하세요 ${displayName}님!',
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

class TodayPlanCard extends StatelessWidget {
  const TodayPlanCard({super.key});

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
                '오늘의 계획',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              Text(
                '편집',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFE27E76),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 첫 과목 그룹
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ColorDot(color: Color(0xFFD8645C)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Text(
                          '데이터베이스',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: Color(0xFFBEBEBE),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _CheckRow(
                      checkedColor: Color(0xFFD8645C),
                      text: 'SQLite 실습',
                      checked: true,
                    ),
                    SizedBox(height: 6),
                    _CheckRow(
                      checkedColor: Color(0xFFE5E5E5),
                      text: 'SQL 기본 쿼리 복습',
                      checked: false,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E3E4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'D - 17',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8D6B6C),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(
            height: 1.5,
            width: 170,
            color: const Color(0xFFE7A6A0),
          ),
          const SizedBox(height: 14),

          // 두 번째 과목 그룹
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ColorDot(color: Color(0xFF6FA43E)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '인터넷 프로그래밍',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    _CheckRow(
                      checkedColor: Color(0xFF6FA43E),
                      text: 'map / filter / reduce 연습 문제',
                      checked: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final Color checkedColor;
  final String text;
  final bool checked;

  const _CheckRow({
    required this.checkedColor,
    required this.text,
    required this.checked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: checked ? checkedColor : const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(4),
          ),
          child: checked
              ? const Icon(
                  Icons.check,
                  size: 11,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color:
                  checked ? const Color(0xFF333333) : const Color(0xFF7F7F7F),
              fontWeight: checked ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
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

  const BottomNavBar({
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
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 180),
                      pageBuilder: (context, animation, _) => CalendarPageShell(
                        currentIndex: 1,
                        onTapNav: onTapNav,
                      ),
                      transitionsBuilder: (context, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
              ),
              TomatoNavItem(),
              NavItem(
                icon: Icons.bar_chart,
                label: 'Report',
                active: false,
                onTap: () {},
              ),
              NavItem(
                icon: Icons.book,
                label: 'Subject',
                active: false,
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 180),
                      pageBuilder: (context, animation, _) => SubjectPageShell(
                        currentIndex: 2,
                        onTapNav: onTapNav,
                      ),
                      transitionsBuilder: (context, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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

class TomatoNavItem extends StatelessWidget {
  const TomatoNavItem({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPomodoroStartModal(context),
      child: Column(
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
      ),
    );
  }
}
