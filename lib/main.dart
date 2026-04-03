import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const SmarttoApp());
}

class SmarttoApp extends StatelessWidget {
  const SmarttoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF6F6F3),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int currentPage = 0;
  final TextEditingController nicknameController = TextEditingController();

  String selectedPurpose = '';
  String selectedStudyTime = '';

  final List<Map<String, String>> purposeOptions = const [
    {'title': '대학생', 'subtitle': '수능 · 시험 · 시험'},
    {'title': '수험생', 'subtitle': '자격증 · 공무원'},
    {'title': '자기계발', 'subtitle': '자유 학습'},
  ];

  final List<String> timeOptions = const ['1시간', '2시간', '4시간', '5시간+'];

  @override
  void dispose() {
    _pageController.dispose();
    nicknameController.dispose();
    super.dispose();
  }

  void goNext() {
    if (currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  bool get canGoNext {
    switch (currentPage) {
      case 0:
        return true; // splash
      case 1:
        return true;
      case 2:
        return nicknameController.text.trim().isNotEmpty;
      case 3:
        return selectedPurpose.isNotEmpty;
      case 4:
        return selectedStudyTime.isNotEmpty;
      case 5:
        return true;
      default:
        return false;
    }
  }

  String get buttonText {
    switch (currentPage) {
      case 2:
      case 3:
      case 4:
        return '다음';
      case 5:
        return '첫 과목 추가하기';
      default:
        return '';
    }
  }

  void onBottomButtonPressed() {
    if (!canGoNext) return;
    goNext();
  }

  bool get showBottomButton {
  return currentPage != 0 && currentPage != 1 && currentPage != 5;
}
    void goPrev() {
  if (currentPage > 0) {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        children: [
          SplashPage(
            onFinished: goNext,
          ),

           IntroGuidePage(
            onStart: goNext, 
          ),

          NicknamePage(
            controller: nicknameController,
            onChanged: (_) => setState(() {}),
            onBack: goPrev,
          ),
          PurposePage(
            options: purposeOptions,
            selectedPurpose: selectedPurpose,
            onSelect: (value) {
              setState(() {
                selectedPurpose = value;
              });
            },
            onBack: goPrev,
          ),
          StudyTimePage(
            options: timeOptions,
            selectedTime: selectedStudyTime,
            onSelect: (value) {
              setState(() {
                selectedStudyTime = value;
              });
            },
            onBack: goPrev,
          ),
          CompletePage(
            nickname: nicknameController.text.trim(),
            selectedStudyTime: selectedStudyTime,
          ),
          const SizedBox.shrink(),
        ],
      ),
    ),
  ),
),
      bottomNavigationBar: showBottomButton
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canGoNext ? onBottomButtonPressed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F2F2F),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class SplashPage extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashPage({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF6EF), // ✅ 배경색 변경
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🍅 토마토 (뒤 배경)
            Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                color: Color(0xFFD98C8C), // 토마토 색
                shape: BoxShape.circle,
              ),
            ),

            // 🍃 꼭지 (위쪽)
            Positioned(
              top: 110,
              child: Transform.rotate(
                angle: -0.2,
                child: const Icon(
                  Icons.eco,
                  size: 90,
                  color: Color(0xFFA8C686),
                ),
              ),
            ),

            // 📝 텍스트
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'SMARTTO',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Focus Your Study',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IntroGuidePage extends StatelessWidget {
  final VoidCallback onStart;

  const IntroGuidePage({
    super.key,
    required this.onStart,
    });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF6EF),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  const _IntroStatusBar(),
                  const Spacer(),
                  Column(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD95C4F),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🍅',
                          style: TextStyle(fontSize: 56),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'SMARTTO가 당신의 집중 상태를',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '실시간으로 분석해 최적의 학습 리듬을 만들어드려요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF444444),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    '1분도 안 걸려요!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF777777),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4A261),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '시작하기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class _IntroStatusBar extends StatelessWidget {
  const _IntroStatusBar();

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

class NicknamePage extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;

  const NicknamePage({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = controller.text.trim();

    return OnboardingLayout(
      stepIndex: 0,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlaceholderImageBox(size: 36),
          const SizedBox(height: 20),
          const Text(
            '사용할 닉네임을 설정해 주세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: '이름 또는 닉네임 입력',
              hintStyle: TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 13,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFBDBDBD)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF4A261), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (nickname.isNotEmpty)
            Text(
              '반갑습니다! ${nickname}님 😊',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF777777),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class PurposePage extends StatelessWidget {
  final List<Map<String, String>> options;
  final String selectedPurpose;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;

  const PurposePage({
    super.key,
    required this.options,
    required this.selectedPurpose,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      stepIndex: 1,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PlaceholderImageBox(size: 36),
          const SizedBox(height: 20),
          const Text(
            '어떤 목적으로 공부하시나요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 20),
          ...options.map((option) {
            final title = option['title']!;
            final subtitle = option['subtitle']!;
            final isSelected = selectedPurpose == title;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(title),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF3E8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF4A261)
                          : const Color(0xFFE4E4E4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const PlaceholderImageBox(size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFFF4A261)
                                    : const Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isSelected
                            ? const Color(0xFFF4A261)
                            : const Color(0xFFD0D0D0),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class StudyTimePage extends StatelessWidget {
  final List<String> options;
  final String selectedTime;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;

  const StudyTimePage({
    super.key,
    required this.options,
    required this.selectedTime,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingLayout(
      stepIndex: 2,
      onBack: onBack,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PlaceholderImageBox(size: 36),
            const SizedBox(height: 20),
            const Text(
              '목표를 설정해 주세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF232323),
              ),
            ),
            const SizedBox(height: 22),
            GridView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = selectedTime == option;

                return GestureDetector(
                  onTap: () => onSelect(option),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAF8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFF4A261)
                            : const Color(0xFFE6D2BF),
                        width: isSelected ? 2 : 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFD9D9D9),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            size: 18,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          option,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFFF4A261)
                                : const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class CompletePage extends StatelessWidget {
  final String nickname;
  final String selectedStudyTime;

  const CompletePage({
    super.key,
    required this.nickname,
    required this.selectedStudyTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: const [
              SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF4A261),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF4A261),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF4A261),
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9D9D9)),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 42,
              color: Color(0xFFC7C7C7),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '준비 완료!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 170,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 170,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E8E8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MainScreen(
                      nickname: nickname,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A261),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                '첫 과목 추가하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingLayout extends StatelessWidget {
  final int stepIndex;
  final Widget child;
  final VoidCallback? onBack;

  const OnboardingLayout({
    super.key,
    required this.stepIndex,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFF4A261);
    const inactiveColor = Color(0xFFD9D9D9);

    Widget bar(bool active) {
      return Expanded(
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: 
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 12),
              bar(stepIndex >= 0),
              const SizedBox(width: 8),
              bar(stepIndex >= 1),
              const SizedBox(width: 8),
              bar(stepIndex >= 2),
            ],
          ),
          const SizedBox(height: 36),
          child,
        ],
      ),
    );
  }
}

class PlaceholderImageBox extends StatelessWidget {
  final double size;

  const PlaceholderImageBox({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D37),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}