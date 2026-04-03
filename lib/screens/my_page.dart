import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyPage extends StatefulWidget {
  final String initialNickname;
  final String? initialProfileImagePath;

  const MyPage({
    super.key,
    required this.initialNickname,
    this.initialProfileImagePath,
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

    Navigator.pop(context, {
      'nickname': newNickname,
      'profileImagePath': _profileImagePath,
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedNickname = _nicknameController.text.trim().isEmpty
        ? _currentNickname
        : _nicknameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF0),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                        onTap: () {
                        Navigator.pop(context);
                        },
                        child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Colors.black,
                        ),
                    ),
                    ),
                    const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFF15100D),
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
                        side: const BorderSide(color: Color(0xFFD6D6D6)),
                        foregroundColor: const Color(0xFF666666),
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
                        style: TextStyle(fontSize: 11),
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
                      color: const Color(0xFFF0EFEB),
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
                        backgroundColor: const Color(0xFFFBE8E7),
                        foregroundColor: const Color(0xFFD49AA0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(
                            color: Color(0xFFE6B7BC),
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '저장하기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _MyPageBottomNav(),
                ],
              ),
            ),
          ),
        ),
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
  const _MyPageBottomNav();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _NavIcon(icon: Icons.home, label: 'Home', active: true),
          _NavIcon(icon: Icons.calendar_month, label: 'Calendar'),
          _PomodoroIcon(),
          _NavIcon(icon: Icons.bar_chart, label: 'Report'),
          _NavIcon(icon: Icons.subject, label: 'Subject'),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavIcon({
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
        Icon(icon, color: color, size: 24),
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

class _PomodoroIcon extends StatelessWidget {
  const _PomodoroIcon();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFD94C43),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            '🍅',
            style: TextStyle(fontSize: 24),
          ),
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