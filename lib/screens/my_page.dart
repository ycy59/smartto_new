import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subject_page.dart';
import 'calendar_page.dart';

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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const _MyPageStatusBar(),
                  const SizedBox(height: 14),
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
                        backgroundColor: const Color(0xFFF6E1DF),
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
                          color: Color(0xFFD49AA0),
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
                  const SizedBox(height: 26),
                  _MyPageBottomNav(
                    currentIndex: widget.currentIndex,
                    onTapNav: widget.onTapNav,
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

class _MyPageStatusBar extends StatelessWidget {
  const _MyPageStatusBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
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
    );
  }
}

class _MyPageBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapNav;

  const _MyPageBottomNav({
    required this.currentIndex,
    required this.onTapNav,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CalendarPageShell(
                        currentIndex: 1,
                        onTapNav: onTapNav,
                      ),
                    ),
                );
            },
          ),
          const _TomatoNavItem(),
          _NavIcon(
            icon: Icons.bar_chart,
            label: 'Report',
            active: false,
            onTap: () {},
          ),
          _NavIcon(
            icon: Icons.book,
            label: 'Subject',
            active: false,
            onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SubjectPageShell(
                            currentIndex: 2,
                            onTapNav: onTapNav,
                        )
                    )
                );
            }
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
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
  const _TomatoNavItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ClipOval(
            child: Image.asset(
              'assets/images/tomato_glasses.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}