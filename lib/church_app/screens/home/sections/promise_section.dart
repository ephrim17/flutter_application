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
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                child: PromiseVerseCard()),
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
    final width = MediaQuery.of(context).size.width;

    //final double height = cardHeight(PromiseSection().id) * 0.5;

    return promiseWordAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(e.toString()),
      data: (verse) {
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
              width: width - 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    verse['tamil']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    verse['english']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ScriptureReferencePill(
                    reference: verse['reference']!,
                    fontSize: 14,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
