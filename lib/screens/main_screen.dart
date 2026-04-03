import 'package:flutter/material.dart';
import 'package:smartto_new/screens/my_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final String nickname;

  const MainScreen({
    super.key,
    required this.nickname,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

 class _MainScreenState extends State<MainScreen> {
  late String nickname;
  String? profileImagePath;

  @override
  void initState() {
    super.initState();
    nickname = widget.nickname;
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNickname = prefs.getString('nickname');
    final savedProfileImagePath = prefs.getString('profileImagePath');

    if (!mounted) return;

    setState(() {
      nickname = savedNickname ?? widget.nickname;
      profileImagePath = savedProfileImagePath;
    });
  }

  Future<void> _openMyPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MyPage(
          initialNickname: nickname,
          initialProfileImagePath: profileImagePath,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      nickname = result['nickname'] as String? ?? nickname;
      profileImagePath = result['profileImagePath'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                children: [
                  _StatusBar(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          GreetingCard(
                            nickname: nickname,
                            onTapProfile: _openMyPage,
                          ),
                          const SizedBox(height: 14),
                          const TodayPlanCard(),
                          const SizedBox(height: 14),
                          const WeeklyStatsCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  BottomNavBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
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
  final VoidCallback onTapProfile;

  const GreetingCard({
    super.key,
    required this.nickname,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '안녕하세요 ${nickname.isEmpty ? '이용자' : nickname}님!',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF555555),
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
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTapProfile,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TimeInfoBox(
                  title: '학습 시간',
                  value: '1H 25M',
                  changeText: '▲ 12.5%',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: TimeInfoBox(
                  title: '목표 시간',
                  value: '3H 00M',
                  changeText: '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TimeInfoBox extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;

  const TimeInfoBox({
    super.key,
    required this.title,
    required this.value,
    required this.changeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EAEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE7D5D5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          if (changeText.isNotEmpty)
            Text(
              changeText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC75A52),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '오늘의 계획',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              Text(
                '편집',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE06A5F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          PlanRow(
            color: Color(0xFFD8645C),
            text: '알고리즘 - Chapter1 복습',
            status: '완료',
            statusColor: Color(0xFFE06A5F),
          ),
          SizedBox(height: 12),
          PlanRow(
            color: Color(0xFF6AAB3E),
            text: '알고리즘 - 12문제 풀기',
            status: '완료',
            statusColor: Color(0xFF6AAB3E),
          ),
          SizedBox(height: 12),
          PlanRow(
            color: Color(0xFFE3A53F),
            text: '알고리즘 - 버블정렬 코드 구현',
            status: '미완료',
            statusColor: Color(0xFFE3A53F),
          ),
          SizedBox(height: 16),
          _PurpleDivider(),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                '완료',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                '2',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurpleDivider extends StatelessWidget {
  const _PurpleDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF6E1DF),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class PlanRow extends StatelessWidget {
  final Color color;
  final String text;
  final String status;
  final Color statusColor;

  const PlanRow({
    super.key,
    required this.color,
    required this.text,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          status,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class WeeklyStatsCard extends StatelessWidget {
  const WeeklyStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '이번 주 통계',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              Spacer(),
              Text(
                '상세 보기',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFE06A5F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatItem(
                bgColor: Color(0xFFF4D7D4),
                iconColor: Color(0xFFD7645D),
                icon: Icons.timer,
                value: '0분',
                label: '총 집중',
              ),
              StatItem(
                bgColor: Color(0xFFDDEBD1),
                iconColor: Color(0xFF6AAB3E),
                icon: Icons.check_circle,
                value: '0개',
                label: '완료 세션',
              ),
              StatItem(
                bgColor: Color(0xFFF7E3B8),
                iconColor: Color(0xFFE3A53F),
                icon: Icons.person,
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
  final Color bgColor;
  final Color iconColor;
  final IconData icon;
  final String value;
  final String label;

  const StatItem({
    super.key,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF555555),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          NavItem(
            icon: Icons.home,
            label: 'Home',
            active: true,
          ),
          NavItem(
            icon: Icons.calendar_month,
            label: 'Calendar',
          ),
          TomatoNavItem(),
          NavItem(
            icon: Icons.bar_chart,
            label: 'Report',
          ),
          NavItem(
            icon: Icons.book,
            label: 'Subject',
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

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF5A3D2C) : const Color(0xFFB8B8B8);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class TomatoNavItem extends StatelessWidget {
  const TomatoNavItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFD94C43),
                shape: BoxShape.circle,
              ),
            ),
            const Text(
              '🍅',
              style: TextStyle(fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          '토마토\n(뽀모도로)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: Color(0xFF7C7C7C),
            height: 1.0,
          ),
        ),
      ],
    );
  }
}