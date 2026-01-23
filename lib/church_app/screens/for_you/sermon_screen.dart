import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/sermon_providers.dart';
import 'package:flutter_application/church_app/widgets/sermon_card_widget.dart';
import 'package:flutter_application/church_app/widgets/sermon_player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SermonsScreen extends ConsumerWidget {
  const SermonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sermonsAsync = ref.watch(sermonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sermons')),
      body: sermonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (sermons) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sermons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sermon = sermons[index];
            return SermonCard(
              youtubeUrl: sermon.url,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return SermonPlayer(
                        sermon,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


