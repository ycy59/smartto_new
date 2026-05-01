import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'camera_page.dart';
import 'subject_page.dart';
import 'calendar_page.dart';
import 'main_screen.dart';
import 'report_page.dart';

class MyPage extends StatefulWidget {
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
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
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

  void _goBackToMain() {
  Navigator.pop(context);
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
      builder: (context) => CameraPage(
        initialSelectedTask: null,
        allTasks: [],
      ),
    ),
  );
}

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim().isEmpty
        ? _currentNickname
        : _nicknameController.text.trim();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Alert'),
          content: const Text('닉네임을 변경하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
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
  final displayedNickname = _nicknameController.text.trim().isEmpty
      ? _currentNickname
      : _nicknameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: const Color(0xFF1C1C1C),
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
                                child: Text(
                                  '🍅 $displayedNickname',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: _pickProfileImage,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE0E0E0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text(
                                '프로필 이미지 수정',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '닉네임 변경',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9D9D9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nicknameController,
                                    decoration: const InputDecoration(
                                      hintText: '닉네임 입력',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFB3B3B3),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _nicknameController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 140,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _saveNickname,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(
                                    color: Color(0xFFF299B2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                '저장하기',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEE7E76),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 34,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAEAEA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
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
                  _MyPageBottomNav(
                    currentIndex: widget.currentIndex,
                    onTapNav: widget.onTapNav,
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

class _MyPageBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;
  final String nickname;
  final String? profileImagePath;
  final VoidCallback onTapTomato;

  const _MyPageBottomNav({
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
          top: BorderSide(
            color: Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.home,
            label: 'Home',
            active: currentIndex == 0,
            onTap: () => onTapNav(0),
          ),
          _NavIcon(
            icon: Icons.calendar_month,
            label: 'Calendar',
            active: false,
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => CalendarPageShell(
                    currentIndex: 1,
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
          _TomatoNavItem(onTap: onTapTomato),
          _NavIcon(
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
          _NavIcon(
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

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? const Color(0xFFE08C84) : const Color(0xFFC8C8C8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
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

class _TomatoNavItem extends StatelessWidget {
  final VoidCallback onTap;

  const _TomatoNavItem({
    required this.onTap,
  });

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
              ),
            ),
          ),
      );
  }
}