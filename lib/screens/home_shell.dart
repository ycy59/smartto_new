import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'my_page.dart';

class HomeShell extends StatefulWidget {
  final String nickname;

  const HomeShell({
    super.key,
    required this.nickname,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PageController _pageController;
  String currentNickname = '';
  String? currentProfileImagePath;

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
    _pageController = PageController(initialPage: 0);
  }

  void updateProfile({
    required String nickname,
    String? profileImagePath,
  }) {
    setState(() {
      currentNickname = nickname;
      currentProfileImagePath = profileImagePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: [
        MainScreen(
          nickname: currentNickname,
          profileImagePath: currentProfileImagePath,
        ),
        MyPage(
          initialNickname: currentNickname,
          initialProfileImagePath: currentProfileImagePath,
          onProfileUpdated: updateProfile,
        ),
      ],
    );
  }
}