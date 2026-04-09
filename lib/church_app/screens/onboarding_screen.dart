import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/onboarding_provider.dart';
import 'package:flutter_application/church_app/widgets/praisethelord_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(onboardingPagesProvider);
    final theme = Theme.of(context);
    final accent = const Color(0xFF5B7CFA);
    final actionColor = const Color(0xFF8C5AF7);
    final surface = const Color(0xFFF8F7FD);

    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: surface,
        colorScheme: theme.colorScheme.copyWith(
          primary: accent,
          secondary: actionColor,
          surface: surface,
        ),
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF9F8FE),
                Color(0xFFF3F4FB),
                Color(0xFFF7F6FC),
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
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: totalPages,
                          onPageChanged: (index) {
                            setState(() => _currentIndex = index);
                          },
                          itemBuilder: (context, index) {
                            if (index == pages.length) {
                              return const _PraiseTheLordPage();
                            }

                            final page = pages[index];
                            return _OnboardingContentPage(
                              title: page.title,
                              description: page.description,
                              accent: accent,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PageDots(
                              count: totalPages,
                              currentIndex: _currentIndex,
                              activeColor: accent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _PrimaryActionButton(
                            label: isLast
                                ? context.t(
                                    'onboarding.get_started',
                                    fallback: 'Get Started',
                                  )
                                : context.t(
                                    'onboarding.next',
                                    fallback: 'Next',
                                  ),
                            color: actionColor,
                            onPressed: () {
                              if (isLast) {
                                _completeOnboarding();
                              } else {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            },
                          ),
                        ],
                      ),
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

class _OnboardingContentPage extends StatelessWidget {
  const _OnboardingContentPage({
    required this.title,
    required this.description,
    required this.accent,
  });

  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 720;
        final heroSize = compact ? 220.0 : 270.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.only(
                top: compact ? 8 : 20,
                bottom: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: _HeroTile(
                      size: heroSize,
                      title: title,
                      accent: accent,
                    ),
                  ),
                  SizedBox(height: compact ? 28 : 40),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: compact ? 38 : 44,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6C6A83),
                          letterSpacing: -1.3,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          height: 1.45,
                          color: const Color(0xFF8B889F),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PraiseTheLordPage extends StatelessWidget {
  const _PraiseTheLordPage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: const PraiseTheLordCard(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroTile extends StatefulWidget {
  const _HeroTile({
    required this.size,
    required this.title,
    required this.accent,
  });

  final double size;
  final String title;
  final Color accent;

  @override
  State<_HeroTile> createState() => _HeroTileState();
}

class _HeroTileState extends State<_HeroTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tileSize = widget.size * 0.54;
    final heroIcon = _heroIconForTitle(widget.title);

    return _HeroBadge(
      accent: widget.accent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final orbit = _controller.value * 6.28318530718;
          return SizedBox(
            height: tileSize + 76,
            width: tileSize + 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _OrbitIcon(
                  angle: orbit,
                  distance: tileSize * 0.54,
                  icon: heroIcon.secondary,
                  color: heroIcon.glow,
                ),
                _OrbitIcon(
                  angle: orbit + 2.1,
                  distance: tileSize * 0.48,
                  icon: heroIcon.tertiary,
                  color: widget.accent.withValues(alpha: 0.28),
                  size: 14,
                ),
                _OrbitIcon(
                  angle: orbit + 4.2,
                  distance: tileSize * 0.52,
                  icon: Icons.circle,
                  color: heroIcon.glow.withValues(alpha: 0.42),
                  size: 12,
                ),
                child!,
              ],
            ),
          );
        },
        child: Container(
          height: tileSize,
          width: tileSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                heroIcon.base,
                widget.accent,
              ],
            ),
            borderRadius: BorderRadius.circular(tileSize * 0.26),
            boxShadow: [
              BoxShadow(
                color: heroIcon.glow.withValues(alpha: 0.30),
                blurRadius: 34,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: _HeroIcon(
            icon: heroIcon.center,
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.child,
    required this.accent,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      width: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.10),
                  accent.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 38,
            right: 38,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        size: 68,
        color: Colors.white.withValues(alpha: 0.96),
      ),
    );
  }
}

class _OrbitIcon extends StatelessWidget {
  const _OrbitIcon({
    required this.angle,
    required this.distance,
    required this.icon,
    required this.color,
    this.size = 18,
  });

  final double angle;
  final double distance;
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        distance * cos(angle),
        distance * sin(angle) * 0.76,
      ),
      child: Container(
        height: size + 12,
        width: size + 12,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _HeroIconSet {
  const _HeroIconSet({
    required this.center,
    required this.secondary,
    required this.tertiary,
    required this.base,
    required this.glow,
  });

  final IconData center;
  final IconData secondary;
  final IconData tertiary;
  final Color base;
  final Color glow;
}

_HeroIconSet _heroIconForTitle(String title) {
  final value = title.toLowerCase();

  if (value.contains('verse') || value.contains('word')) {
    return const _HeroIconSet(
      center: Icons.menu_book_rounded,
      secondary: Icons.auto_stories_rounded,
      tertiary: Icons.bookmark_rounded,
      base: Color(0xFF42C8B7),
      glow: Color(0xFF7BE7D4),
    );
  }

  if (value.contains('event') || value.contains('calendar')) {
    return const _HeroIconSet(
      center: Icons.event_available_rounded,
      secondary: Icons.notifications_active_rounded,
      tertiary: Icons.celebration_rounded,
      base: Color(0xFF67A9FF),
      glow: Color(0xFFA8D0FF),
    );
  }

  if (value.contains('article') || value.contains('read')) {
    return const _HeroIconSet(
      center: Icons.chrome_reader_mode_rounded,
      secondary: Icons.library_books_rounded,
      tertiary: Icons.lightbulb_rounded,
      base: Color(0xFF6F9DFF),
      glow: Color(0xFFA9C3FF),
    );
  }

  if (value.contains('plan') || value.contains('learn')) {
    return const _HeroIconSet(
      center: Icons.auto_awesome_rounded,
      secondary: Icons.track_changes_rounded,
      tertiary: Icons.insights_rounded,
      base: Color(0xFF37CDAF),
      glow: Color(0xFFB4F1DF),
    );
  }

  if (value.contains('church') || value.contains('community')) {
    return const _HeroIconSet(
      center: Icons.groups_rounded,
      secondary: Icons.favorite_rounded,
      tertiary: Icons.forum_rounded,
      base: Color(0xFF6F9DFF),
      glow: Color(0xFFC0D6FF),
    );
  }

  return const _HeroIconSet(
    center: Icons.document_scanner_rounded,
    secondary: Icons.payments_rounded,
    tertiary: Icons.check_circle_rounded,
    base: Color(0xFF4ED0BC),
    glow: Color(0xFFBAF3E8),
  );
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
  });

  final int count;
  final int currentIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(
        count,
        (index) {
          final isActive = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.only(right: 8),
            height: 9,
            width: isActive ? 26 : 9,
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : const Color(0xFFDCCFF9).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.86),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.26),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
