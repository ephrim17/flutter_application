import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/daily_verse_providers.dart';
import 'package:flutter_application/church_app/providers/language_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/for_you/for_you_card_layout.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/decorated_scripture_card_widget.dart';
import 'package:flutter_application/church_app/widgets/language_toggle_widget.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DailyVerseSection implements MasterSection {
  const DailyVerseSection();

  @override
  String get id => 'dailyVerse';

  @override
  int get order => 10;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              DailyVerseCard(),
            ],
          ),
        ),
      ),
    ];
  }
}

class DailyVerseCard extends ConsumerWidget {
  const DailyVerseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(dailyVerseLanguageProvider);
    final width = MediaQuery.of(context).size.width;
    final church = ref.watch(selectedChurchProvider);
    final verseRef = ref.watch(appConfigProvider).maybeWhen(
          data: (config) => config.dailyVerseRef,
          orElse: () => null,
        );

    // The card is now the church's generated images, not the verse text —
    // the admin creates one set per language each day in Studio and members
    // read them here. Nothing on this screen can trigger a generation.
    // See KT Files/architecture/daily-verse-card-caching.md.
    final cacheKey = (church == null || verseRef == null)
        ? null
        : DailyVerseCacheKey(
            churchId: church.id,
            language: language == BibleLanguage.tamil
                ? VerseShareLanguage.tamil
                : VerseShareLanguage.english,
            book: verseRef.book,
            chapter: verseRef.chapter,
            verse: verseRef.verse,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: forYouPrimaryCardHeight),
      child: DecoratedScriptureCard(
        width: width - 32,
        plain: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionHeader(
                  text: context.t('daily_verse.title'),
                  padding: 0.0,
                ),
                const Spacer(),
                BibleLanguageToggle(provider: dailyVerseLanguageProvider),
              ],
            ),
            const SizedBox(height: 12),
            if (cacheKey == null)
              _DailyVerseCardsMessage(
                message: context.t('ui.verse_share.ai_cards_unavailable'),
              )
            else
              _DailyVerseCardsCarousel(cacheKey: cacheKey),
          ],
        ),
      ),
    );
  }
}

/// The church's three generated cards for today, swipeable in place; tapping
/// one opens the full-screen viewer at that card, where it can be saved.
class _DailyVerseCardsCarousel extends ConsumerWidget {
  const _DailyVerseCardsCarousel({required this.cacheKey});

  final DailyVerseCacheKey cacheKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dailyVerseCardsProvider(cacheKey));

    // No images anywhere — not today's, and none on any earlier day the
    // server falls back to. Rather than an empty apology, drop to the card
    // this section used before it showed images at all: the verse itself, as
    // text, in whichever language the toggle above is set to.
    return cardsAsync.when(
      loading: () => const SizedBox(
        height: 260,
        child: Center(child: AppLoadingIndicator()),
      ),
      error: (_, __) => const _DailyVerseTextFallback(),
      data: (images) => images.isEmpty
          ? const _DailyVerseTextFallback()
          : _DailyVerseCardsPager(images: images),
    );
  }
}

class _DailyVerseCardsPager extends StatefulWidget {
  const _DailyVerseCardsPager({required this.images});

  final List<PickedImageData> images;

  @override
  State<_DailyVerseCardsPager> createState() => _DailyVerseCardsPagerState();
}

class _DailyVerseCardsPagerState extends State<_DailyVerseCardsPager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          // The cards are square (1:1 from Gemini), so height follows the
          // card's own width rather than a fixed guess.
          height: MediaQuery.of(context).size.width - 64,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => showAiVerseCardViewer(
                  context,
                  images: widget.images,
                  initialIndex: index,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    widget.images[index].bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.images.length, (index) {
            final selected = index == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: selected ? 18 : 6,
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// The plain-text Daily Verse, shown when the church has no generated cards
/// to fall back to at all.
///
/// The language toggle lives in the card header above and drives
/// [dailyVerseLanguageProvider], so this only has to render whichever
/// language is selected. Only if the verse itself cannot be read does the
/// section show the "not created yet" message.
class _DailyVerseTextFallback extends ConsumerWidget {
  const _DailyVerseTextFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(dailyVerseLanguageProvider);
    final verseAsync = ref.watch(dailyVerseProviderLocal);

    return verseAsync.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: AppLoadingIndicator()),
      ),
      error: (_, __) => _DailyVerseCardsMessage(
        message: context.t('ui.verse_share.ai_cards_unavailable'),
      ),
      data: (verse) {
        final isTamil = language == BibleLanguage.tamil;
        final text = (isTamil ? verse['tamil'] : verse['english']) ?? '';
        final reference =
            (isTamil ? verse['referenceTamil'] : verse['reference']) ?? '';
        if (text.isEmpty) {
          return _DailyVerseCardsMessage(
            message: context.t('ui.verse_share.ai_cards_unavailable'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 18.0,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ScriptureReferencePill(reference: reference),
          ],
        );
      },
    );
  }
}

class _DailyVerseCardsMessage extends StatelessWidget {
  const _DailyVerseCardsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
