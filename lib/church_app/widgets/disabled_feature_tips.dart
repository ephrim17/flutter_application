import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';

class DisabledFeatureTip {
  const DisabledFeatureTip({required this.title, required this.icon});

  final String title;
  final IconData icon;
}

class DisabledFeatureTipsSliver extends StatelessWidget {
  const DisabledFeatureTipsSliver({super.key, required this.tips});

  final List<DisabledFeatureTip> tips;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SliverToBoxAdapter();
    return SliverToBoxAdapter(
      child: DisabledFeatureTips(tips: tips),
    );
  }
}

class DisabledFeatureTips extends StatelessWidget {
  const DisabledFeatureTips({super.key, required this.tips});

  final List<DisabledFeatureTip> tips;

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: _DisabledFeatureTipStack(tips: tips),
    );
  }
}

class _DisabledFeatureTipStack extends StatefulWidget {
  const _DisabledFeatureTipStack({required this.tips});

  final List<DisabledFeatureTip> tips;

  @override
  State<_DisabledFeatureTipStack> createState() =>
      _DisabledFeatureTipStackState();
}

class _DisabledFeatureTipStackState extends State<_DisabledFeatureTipStack> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 142,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (widget.tips.length > 2)
            Positioned(
              top: 12,
              left: 18,
              right: 18,
              bottom: 4,
              child: _BackCard(
                color: colors.secondaryContainer.withValues(alpha: 0.45),
              ),
            ),
          if (widget.tips.length > 1)
            Positioned(
              top: 6,
              left: 9,
              right: 9,
              bottom: 8,
              child: _BackCard(
                color: colors.primaryContainer.withValues(alpha: 0.62),
              ),
            ),
          Positioned.fill(
            bottom: 12,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.tips.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final tip = widget.tips[index];
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.primaryContainer,
                        foregroundColor: colors.onPrimaryContainer,
                        child: Icon(tip.icon),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                'features.not_added_yet',
                                parameters: {'feature': tip.title},
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t(
                                  'ui.disabled_feature_tips.enable_this_feature_from_studio_when_it_is_ready'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.tips.length > 1)
                        Icon(Icons.swipe_rounded, color: colors.primary),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.tips.length > 1)
            Positioned(
              bottom: 0,
              child: Row(
                children: List.generate(
                  widget.tips.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _currentPage ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? colors.primary
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
