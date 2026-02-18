import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/modals/verse_share_modal.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: "Favorites"),
      ),
      body: favoritesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text("Error: $error"),
        ),
        data: (verses) {
          if (verses.isEmpty) {
            return const Center(
              child: Text(
                "No Favorites yet",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: verses.length,
            itemBuilder: (context, index) {
              final verse = verses[index];

              return Dismissible(
                key: ValueKey(verse['reference']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (_) async {
                  await ref
                      .read(favoritesProvider.notifier)
                      .removeHighlight(verse);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Removed from favorites"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// English
                      Text(
                        verse['english'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// Tamil
                      Text(
                        verse['tamil'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                        verse['reference'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                          Spacer(),
                          InkWell(
                            onTap: () async {
                              _showLanguageShareOptions(
                                context,
                                verse: verse,
                              );
                            },
                            child: Icon(Icons.share, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


void _showLanguageShareOptions(
  BuildContext context, {
  required Map<String, dynamic> verse,
}) {
  showModalBottomSheet(
    context: context,
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              //leading: const Icon(Icons.language),
              title: const Text("Share in English"),
              onTap: () {
                Navigator.pop(context);
                _shareVerse(
                  text: verse['english'],
                  reference: verse['reference'],
                  context: context,
                );
              },
            ),
            ListTile(
              //leading: const Icon(Icons.translate),
              title: const Text("Share in Tamil"),
              onTap: () {
                _shareVerse(
                  text: verse['tamil'],
                  reference: verse['reference'],
                  context: context,
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
Future<void> _shareVerse({
  required String text,
  required String reference,
  required BuildContext context,
}) async {
  showVerseShareModal(
    context,
    text: text,
    reference: reference,
  );
}