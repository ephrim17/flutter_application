import 'package:flutter/material.dart';
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
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verse) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final maxWidth = screenWidth >= 1024 ? 1100.0 : null;

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
                      text: context.t(
                        'promise.section_title',
                        fallback: 'Promise Word 2026',
                      ),
                      padding: 0.0,
                    ),
                    const SizedBox(height: 10),
                    DecoratedScriptureCard(
                      width: availableWidth,
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
