import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/preflow_colors.dart';
import 'package:flutter_application/church_app/providers/onboarding_provider.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState
    extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(onboardingPagesProvider);
    final baseTheme = Theme.of(context);
    final onboardingTheme = baseTheme.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: PreflowColors.card,
      colorScheme: baseTheme.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: PreflowColors.accent,
        secondary: PreflowColors.accent,
        surface: PreflowColors.card,
        onPrimary: PreflowColors.darkText,
        onSurface: PreflowColors.lightText,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PreflowColors.accent,
          foregroundColor: PreflowColors.darkText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      textTheme: baseTheme.textTheme.copyWith(
        headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
          color: PreflowColors.lightText,
        ),
        headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
          color: PreflowColors.lightMutedText,
        ),
        bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
          color: PreflowColors.lightMutedText,
        ),
      ),
    );

    return Theme(
      data: onboardingTheme,
      child: Scaffold(
        backgroundColor: PreflowColors.card,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: const [
                PreflowColors.onboardingGradientBase,
                PreflowColors.card,
              ],
            ),
          ),
          child: pagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                "${context.t('common.error_prefix', fallback: 'Error')}: $e",
              ),
            ),
            data: (pages) {
              if (pages.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _completeOnboarding();
                });
                return const Center(child: CircularProgressIndicator());
              }

              final totalPages = pages.length + 1;
              final isLast = _currentIndex == totalPages - 1;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: totalPages,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                          },
                          itemBuilder: (_, index) {
                            final isLiveCardPage = index == pages.length;

                            if (isLiveCardPage) {
                              return const Center(
                                child: PraiseTheLordCard(),
                              );
                            }

                            final page = pages[index];

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (page.imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Image.network(
                                      page.imageUrl,
                                      height: 260,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(height: 40),
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  page.description,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          totalPages,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 8,
                            width: _currentIndex == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLast) {
                              _completeOnboarding();
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Text(
                            isLast
                                ? context.t(
                                    'onboarding.get_started',
                                    fallback: 'Get Started',
                                  )
                                : context.t(
                                    'onboarding.next',
                                    fallback: 'Next',
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
