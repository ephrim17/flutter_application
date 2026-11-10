import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/home_sections/promise_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _sectionPadding = 16.0;

class PromiseSection implements MasterSection {
  const PromiseSection();

  @override
  String get id => 'promise';

  @override
  int get order => 30;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Consumer(
          builder: (context, ref, _) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: _sectionPadding),
              child: PromiseVerseCard(),
            );
          },
        ),
      ),
    ];
  }
}

class PromiseVerseCard extends ConsumerWidget {
  const PromiseVerseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promiseWordAsync = ref.watch(promiseWordProviderLocal);

    return promiseWordAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verse) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxWidth = homeSectionMaxWidth(screenWidth);
        // The header lines up with the other section headers (16, from the
        // sliver padding); the card lines up with the Events/Announcements
        // carousel cards, which sit further in than their headers. Both boxes
        // are centred, so the difference is between their left edges.
        final carouselWidth = maxWidth ?? screenWidth;
        final carouselCardLeft = (screenWidth - carouselWidth) / 2 +
            homeCarouselCardInset(screenWidth);
        final promiseWidth = math.min(
          screenWidth - _sectionPadding * 2,
          maxWidth ?? double.infinity,
        );
        final promiseLeft = (screenWidth - promiseWidth) / 2;
        final cardInset = math.max(0.0, carouselCardLeft - promiseLeft);

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final isTabletWidth = availableWidth >= 700;
                final tamilStyle =
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.45,
                        );
                final englishStyle =
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      text: context.t('promise.section_title'),
                      padding: 0.0,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: cardInset),
                      child: DecoratedScriptureCard(
                        width: availableWidth - cardInset * 2,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTabletWidth ? 18 : 6,
                            vertical: isTabletWidth ? 12 : 4,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                verse['tamil']!,
                                textAlign: TextAlign.center,
                                style: tamilStyle,
                              ),
                              SizedBox(height: isTabletWidth ? 14 : 10),
                              Text(
                                verse['english']!,
                                textAlign: TextAlign.center,
                                style: englishStyle,
                              ),
                              SizedBox(height: isTabletWidth ? 16 : 12),
                              ScriptureReferencePill(
                                reference: verse['reference']!,
                                fontSize: isTabletWidth ? 15 : 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
