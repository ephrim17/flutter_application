import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final notifier = ref.read(favoritesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: "Favorite Verses"),
      ),
      body: favorites.isEmpty
          ? const Center(child: Text('No favorites yet ❤️'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const Divider(
                height: 32,
                thickness: 1,
              ),
              itemBuilder: (context, index) {
                final verse = favorites[index];

                return Dismissible(
                  key: ValueKey(verse.reference),
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
                  onDismissed: (_) {
                    notifier.toggle(verse);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from favorites'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// English
                        Text(
                          verse.english,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          verse.reference,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 12),

                        /// Tamil
                        Text(
                          verse.tamil,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          verse.reference,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
