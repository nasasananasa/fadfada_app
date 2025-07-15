// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../widgets/auth_wrapper.dart'; // Make sure this path is correct

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  bool _isLastPage = false;

  // This function marks that the user has seen the onboarding
  // and navigates them to the main app (AuthWrapper or LoginScreen)
  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _isLastPage = (index == 2);
              });
            },
            children: [
              _buildPage(
                // ⚠️  تنبيه: قم باستبدال اسم الملف باسم ملف الـ GIF الأول لديك
                imagePath: 'assets/images/intro_1.gif',
                title: 'أهلاً بك في فضفضة',
                subtitle: 'مساحتك الآمنة للتعبير عن كل ما في داخلك، بحرية وخصوصية تامة.',
              ),
              _buildPage(
                // ⚠️  تنبيه: قم باستبدال اسم الملف باسم ملف الـ GIF الثاني لديك
                imagePath: 'assets/images/intro_2.gif',
                title: 'صديق وداعم',
                subtitle: 'أنا هنا لأكون صديقك الداعم. لكن تذكر، أنا لست طبيباً نفسياً ويجب استشارة مختص للتشخيص الطبي.',
              ),
              _buildPage(
                isLastPage: true,
                title: 'جاهز للبداية؟',
                subtitle: 'لنبدأ رحلتنا معًا. خصوصيتك هي أولويتنا القصوى.',
                onGetStarted: _finishOnboarding,
              ),
            ],
          ),
          Container(
            alignment: const Alignment(0, 0.85),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Skip Button
                TextButton(
                  onPressed: _finishOnboarding,
                  child: const Text('تخطّي'),
                ),

                // Page Indicator
                SmoothPageIndicator(
                  controller: _pageController,
                  count: 3,
                  effect: WormEffect(
                    dotHeight: 12,
                    dotWidth: 12,
                    activeDotColor: Theme.of(context).primaryColor,
                  ),
                ),

                // Next / Done Button
                _isLastPage
                    ? TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text('ابدأ الآن'),
                      )
                    : TextButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeIn,
                          );
                        },
                        child: const Text('التالي'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage({
    String? imagePath,
    required String title,
    required String subtitle,
    bool isLastPage = false,
    VoidCallback? onGetStarted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLastPage)
            Image.asset(
              imagePath!,
              height: MediaQuery.of(context).size.height * 0.4,
            )
          else
             SizedBox(height: MediaQuery.of(context).size.height * 0.4, child: const Icon(Icons.favorite_rounded, size: 150, color: Colors.pinkAccent)),

          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
          ),
          if (isLastPage) ...[
            const SizedBox(height: 48),
            ElevatedButton(
                onPressed: onGetStarted,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                ),
                child: const Text('تسجيل الدخول باستخدام جوجل'),
            )
          ]
        ],
      ),
    );
  }
}