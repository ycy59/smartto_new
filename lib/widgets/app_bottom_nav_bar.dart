import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../screens/calendar_page.dart';
import '../screens/main_screen.dart';
import '../screens/report_page.dart';
import '../screens/subject_page.dart';

/// 앱 전체에서 사용하는 하단 네비게이션 바.
///
/// 모든 페이지(Home / Calendar / Subject / Report)에서 동일한 모양/동작을 보장.
/// 토마토 CTA(중앙)는 항상 펄스 애니메이션 + 탭 squish 피드백.
enum AppNavTab { home, calendar, subject, report }

class AppBottomNavBar extends ConsumerWidget {
  final AppNavTab activeTab;
  final String nickname;
  final String? profileImagePath;
  final VoidCallback onTapTomato;

  /// Home shell(MainScreen) 내부에서 사용할 때 페이지 전환 콜백.
  /// 주어지면 Home 탭 탭 시 이 콜백 호출. 그 외 화면(Calendar / Subject / Report)에서는
  /// null 로 두면 Home 탭 시 MainScreen 으로 pushAndRemoveUntil.
  final ValueChanged<int>? onTapNav;

  const AppBottomNavBar({
    super.key,
    required this.activeTab,
    required this.nickname,
    required this.onTapTomato,
    this.profileImagePath,
    this.onTapNav,
  });

  void _gotoMain(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainScreen(
          nickname: nickname,
          profileImagePath: profileImagePath,
          currentIndex: 0,
          onTapNav: onTapNav ?? (_) {},
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      (route) => false,
    );
  }

  void _pushReplace(BuildContext context, Widget Function() build) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => build(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home,
            label: 'Home',
            active: activeTab == AppNavTab.home,
            onTap: () {
              // home shell(MainScreen) 안 → onTapNav 로 PageView 내 페이지 전환
              // MyPage / 다른 shell → MainScreen 으로 돌아가기
              if (activeTab == AppNavTab.home && onTapNav != null) {
                onTapNav!(0);
              } else {
                _gotoMain(context);
              }
            },
          ),
          _NavItem(
            icon: Icons.calendar_month,
            label: 'Calendar',
            active: activeTab == AppNavTab.calendar,
            onTap: () {
              if (activeTab == AppNavTab.calendar) return;
              _pushReplace(
                context,
                () => CalendarPageShell(
                  currentIndex: 1,
                  onTapNav: onTapNav ?? (_) {},
                  nickname: nickname,
                  profileImagePath: profileImagePath,
                ),
              );
            },
          ),
          _TomatoCta(onTap: onTapTomato),
          _NavItem(
            icon: Icons.bar_chart,
            label: 'Report',
            active: activeTab == AppNavTab.report,
            onTap: () {
              if (activeTab == AppNavTab.report) return;
              _pushReplace(
                context,
                () => ReportPageShell(
                  currentIndex: 3,
                  onTapNav: onTapNav ?? (_) {},
                  nickname: nickname,
                  profileImagePath: profileImagePath,
                ),
              );
            },
          ),
          _NavItem(
            icon: Icons.book,
            label: 'Subject',
            active: activeTab == AppNavTab.subject,
            onTap: () {
              if (activeTab == AppNavTab.subject) return;
              _pushReplace(
                context,
                () => SubjectPageShell(
                  currentIndex: 2,
                  onTapNav: onTapNav ?? (_) {},
                  nickname: nickname,
                  profileImagePath: profileImagePath,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _NavItem — 아이콘 + 라벨 + 탭 스케일
// ─────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? const Color(0xFFD97068)
        : const Color(0xFFBDBDBD);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(widget.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight:
                    widget.active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _TomatoCta — 중앙 토마토 (펄스 + 탭 squish)
// ─────────────────────────────────────────────
class _TomatoCta extends StatefulWidget {
  final VoidCallback onTap;
  const _TomatoCta({required this.onTap});

  @override
  State<_TomatoCta> createState() => _TomatoCtaState();
}

class _TomatoCtaState extends State<_TomatoCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 46,
            height: 46,
            child: ClipOval(
              child: Image.asset(
                'assets/images/tomato_glasses.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
