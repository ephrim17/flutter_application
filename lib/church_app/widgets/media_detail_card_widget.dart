import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class MediaDetailCard extends StatelessWidget {
  const MediaDetailCard({
    super.key,
    required this.height,
    required this.topChild,
    required this.badgeText,
    required this.title,
    required this.body,
    this.badgeColor,
  });

  final double height;
  final Widget topChild;
  final String badgeText;
  final String title;
  final String body;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final resolvedBadgeColor = badgeColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      height: height,
      decoration: carouselBoxDecoration(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 9,
              child: SizedBox(
                width: double.infinity,
                child: topChild,
              ),
            ),
            Expanded(
              flex: 11,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 150;
                  final titleStyle = Theme.of(context).textTheme.titleLarge
                      ?.copyWith(
                        fontSize: compact ? 22 : 26,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.08,
                      );
                  final bodyStyle = Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        fontSize: compact ? 15 : 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.70),
                        height: 1.24,
                      );

                  return Container(
                    width: double.infinity,
                    color: Theme.of(context).cardTheme.color,
                    padding: EdgeInsets.fromLTRB(
                      18,
                      compact ? 12 : 16,
                      18,
                      compact ? 14 : 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: resolvedBadgeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: resolvedBadgeColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        SizedBox(height: compact ? 6 : 8),
                        Expanded(
                          child: Text(
                            body,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
