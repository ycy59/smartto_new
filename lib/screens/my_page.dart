import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ 추가
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart'; // ✅ 추가
import '../main.dart' show OnboardingScreen;
import '../providers/today_plan_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'camera_page.dart';

// ✅ StatefulWidget → ConsumerStatefulWidget
class MyPage extends ConsumerStatefulWidget {
  final String initialNickname;
  final String? initialProfileImagePath;
  final void Function({
    required String nickname,
    String? profileImagePath,
  }) onProfileUpdated;
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const MyPage({
    super.key,
    required this.initialNickname,
    this.initialProfileImagePath,
    required this.onProfileUpdated,
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

// ✅ State → ConsumerState
class _MyPageState extends ConsumerState<MyPage> {
  late final TextEditingController _nicknameController;
  late String _currentNickname;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _currentNickname = widget.initialNickname;
    _profileImagePath = widget.initialProfileImagePath;
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _profileImagePath = result.files.single.path!;
    });
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
                            side: BorderSide(
                              color: isDark ? const Color(0xFF444444) : const Color(0xFFE5E5E5), // ✅
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F8F8), // ✅
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

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim().isEmpty
        ? _currentNickname
        : _nicknameController.text.trim();

    final isDark = ref.read(themeProvider) == ThemeMode.dark;
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 38),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '닉네임 변경',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF232323),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '\'$newNickname\'으로 변경하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFF8F8F8F),
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
                                  : const Color(0xFFE5E5E5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFF2C2C2C)
                                : const Color(0xFFF8F8F8),
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
                            '저장',
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

    if (shouldSave != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', newNickname);

    if (_profileImagePath != null) {
      await prefs.setString('profileImagePath', _profileImagePath!);
    }

    if (!mounted) return;

    widget.onProfileUpdated(
      nickname: newNickname,
      profileImagePath: _profileImagePath,
    );

    setState(() {
      _currentNickname = newNickname;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark; // ✅
    final displayedNickname = _nicknameController.text.trim().isEmpty
        ? _currentNickname
        : _nicknameController.text.trim();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F4F2), // ✅
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 100) {
            Navigator.pop(context);
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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        children: [
                          _FadeSlideIn(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFF1C1C1C),
                                  backgroundImage: _profileImagePath != null
                                      ? FileImage(File(_profileImagePath!))
                                      : null,
                                  child: _profileImagePath == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 42,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 280),
                                    // 🍅 이모지 → twemoji_tomato-2.png 이미지로 교체
                                    child: Row(
                                      key: ValueKey(displayedNickname),
                                      children: [
                                        Image.asset(
                                          'assets/images/twemoji_tomato-2.png',
                                          width: 18,
                                          height: 18,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          displayedNickname,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1A1A1A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 50),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _PressableScale(
                                onTap: _pickProfileImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2E2E2E)
                                          : const Color(0xFFEEEEEE),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '프로필 이미지 수정',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFAFAFAF)
                                          : const Color(0xFF8A8A8A),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '닉네임 변경',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 140),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF2E2E2E)
                                      : const Color(0xFFEEEEEE),
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: const Color(0xFF000000)
                                              .withValues(alpha: 0.03),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nicknameController,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                        letterSpacing: -0.2,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '닉네임 입력',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF666666)
                                              : const Color(0xFFBEBEBE),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  _PressableScale(
                                    onTap: () {
                                      _nicknameController.clear();
                                      setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                        color: isDark
                                            ? const Color(0xFF888888)
                                            : const Color(0xFFB3B3B3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 220),
                            child: _PressableScale(
                              onTap: _saveNickname,
                              child: Container(
                                width: 160,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97068),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97068)
                                          .withValues(alpha: 0.28),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  '저장하기',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // ⚠️ TEMP DEBUG: 온보딩 화면 다시 보기 (확인용)
                          // 누르면 라이트 테마로 OnboardingScreen 푸시. 뒤로가기로 복귀.
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Theme(
                                    data: ThemeData(
                                      scaffoldBackgroundColor: Colors.white,
                                      useMaterial3: true,
                                      brightness: Brightness.light,
                                    ),
                                    child: const OnboardingScreen(),
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              '🛠 온보딩 다시 보기 (디버그)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF888888)
                                    : const Color(0xFF9A9A9A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 34,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3A3A3A)
                                  : const Color(0xFFEAEAEA), // ✅
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Dot(active: false),
                                SizedBox(width: 4),
                                _Dot(active: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  AppBottomNavBar(
                    activeTab: AppNavTab.home,
                    nickname: _currentNickname,
                    profileImagePath: _profileImagePath,
                    onTapTomato: _showStartDialog,
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

class _Dot extends StatelessWidget {
  final bool active;

  const _Dot({required this.active});

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
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}