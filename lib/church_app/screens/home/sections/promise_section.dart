import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/home_sections/promise_provider.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            // No padding here: the card insets itself to the carousel card
            // edge, which is not the same as a flat gutter.
            return const PromiseVerseCard();
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
        // The heading and the card both line up with the
        // Events/Announcements carousel cards, by using the same inset those
        // carousels give their own cards. Everything here is measured from
        // the screen, so the card grows and shrinks with the window.
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const cardInset = homeSidePadding;
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
                  padding: cardInset,
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
        );
      },
    );
  }
}
