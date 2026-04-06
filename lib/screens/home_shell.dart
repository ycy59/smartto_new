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

  int currentIndex = 0;
  String currentNickname = '';
  String? currentProfileImagePath;

  @override
  void initState() {
    super.initState();
    currentNickname = widget.nickname;
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void moveToPage(int index) {
    setState(() {
      currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
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
      onPageChanged: (index) {
        setState(() {
          currentIndex = index;
        });
      },
      children: [
        MainScreen(
          nickname: currentNickname,
          profileImagePath: currentProfileImagePath,
          currentIndex: currentIndex,
          onTapNav: moveToPage,
        ),
        MyPage(
          initialNickname: currentNickname,
          initialProfileImagePath: currentProfileImagePath,
          onProfileUpdated: updateProfile,
          currentIndex: currentIndex,
          onTapNav: moveToPage,
        ),
      ],
    );
  }
}