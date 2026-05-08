import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_shell.dart';
import 'utils/db_platform_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabaseFactory();
  runApp(
    const ProviderScope(
      child: SmarttoApp(),
    ),
  );
}

class SmarttoApp extends StatelessWidget {
  const SmarttoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Colors.white);
        }
        final prefs = snapshot.data!;
        final done = prefs.getBool('onboarding_complete') ?? false;
        final nickname = prefs.getString('nickname') ?? '';

        if (done && nickname.isNotEmpty) {
          return HomeShell(nickname: nickname);
        }
        return const OnboardingScreen();
      },
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
    {'title': '대학생', 'subtitle': '수업 · 과제 · 시험', 'icon': 'assets/images/icon_university.jpg'},
    {'title': '수험생', 'subtitle': '수능 · 공무원', 'icon': 'assets/images/icon_exam.jpg'},
    {'title': '자기계발', 'subtitle': '자격증 · 언어', 'icon': 'assets/images/icon_growth.jpg'},
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
  const SplashPage({super.key, required this.onFinished});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFFFF),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 배경 토마토 — 투명도 적용
          Opacity(
            opacity: 0.26, //숫자를 늘릴 수록 진해짐.
            child: Image.asset(
              'assets/images/tomato_splash.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
          // 텍스트 애니메이션
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SMARTTO',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Focus Your Study',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF888888),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  const Spacer(),
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/tomato_glasses.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'SMARTTO가 당신의 집중 상태를',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '실시간으로 분석해 최적의 학습 리듬을 만들어드려요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
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
                          borderRadius: BorderRadius.circular(10),
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
          const Text(
            '사용할 닉네임을 설정해 주세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: '이름 또는 닉네임 입력',
              hintStyle: TextStyle(
                color: Color(0xFFBDBDBD),
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
          // ✅ 상단 아이콘 박스 제거
          const Text(
            '어떤 목적으로 공부하시나요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 26),
          ...options.map((option) {
            final title = option['title']!;
            final subtitle = option['subtitle']!;
            final iconPath = option['icon']!;
            final isSelected = selectedPurpose == title;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => onSelect(title),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF5EB)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF4A261)
                          : const Color(0xFFE3E3E3),
                    ),
                  ),
                  child: Row(
                    children: [
                      // ✅ 실제 이미지 아이콘
                      Image.asset(
                        iconPath,
                        width: 36,
                        height: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFFF4A261)
                                    : const Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9C9C9C),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '목표를 설정해 주세요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF232323),
            ),
          ),
          const SizedBox(height: 26),
          GridView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selectedTime == option;

              return GestureDetector(
                onTap: () => onSelect(option),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF4A261)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF4A261)
                          : const Color(0xFFE7E7E7),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF222222),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            const Text(
              '🎉',
              style: TextStyle(fontSize: 62),
            ),
            const SizedBox(height: 18),
            const Text(
              '준비 완료!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222222),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_complete', true);
                  await prefs.setString('nickname', nickname);
                  await prefs.setString('study_time_goal', selectedStudyTime);

                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeShell(nickname: nickname),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4A261),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                child: const Icon(
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
          const Spacer(),
          child,
          const Spacer(),
        ],
      ),
    );
  }
}