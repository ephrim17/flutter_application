import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/services/user_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

class PrayerRequestScreen extends ConsumerWidget {
  const PrayerRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final segment = ref.watch(prayerSegmentProvider);

    final prayersAsync = segment == PrayerSegment.my
        ? ref.watch(myPrayerRequestsProvider)
        : ref.watch(allPrayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
            text: segment == PrayerSegment.my
                ? 'My Prayer Requests'
                : 'All Prayer Requests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _SegmentControl(isAdmin: isAdmin),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _openAddDialog(context, ref),
      ),
      body: prayersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (prayers) {
          if (prayers.isEmpty) {
            return const Center(
              child: Text('No prayer requests yet'),
            );
          }
          return ListView.builder(
            itemCount: prayers.length,
            itemBuilder: (_, i) {
              final prayer = prayers[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Title: ${prayer.title}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description: ${prayer.description}'),
                      const SizedBox(height: 10),
                      ref.watch(userNameProvider(prayer.userId)).when(
                            loading: () => const Text("By: Loading..."),
                            error: (_, __) => const Text("By: Unknown"),
                            data: (name) => Text("By: ${name?.toUpperCase() ?? "Unknown"}"),
                          ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await ref
                          .read(prayerRepositoryProvider)
                          .deletePrayer(prayer.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Prayer Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          ElevatedButton(
            child: const Text('Submit'),
            onPressed: () async {
              addPrayer(
                titleCtrl,
                descCtrl,
                context,
                ref,
                dialogContext,
              );
            },
          ),
        ],
      ),
    );
  }

  void addPrayer(
      TextEditingController titleCtrl,
      TextEditingController descCtrl,
      BuildContext context,
      WidgetRef ref,
      BuildContext dialogContext) async {
    //validation can be added here
    if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
        ),
      );
      return;
    }
    await ref.read(prayerRepositoryProvider).addPrayer(
          title: titleCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
    if (!context.mounted) return;
    Navigator.pop(dialogContext);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prayer request submitted successfully'),
      ),
    );
  }
}

class _SegmentControl extends ConsumerWidget {
  final bool isAdmin;
  const _SegmentControl({required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(prayerSegmentProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<PrayerSegment>(
        segments: [
          const ButtonSegment(
            value: PrayerSegment.my,
            label: Text('My Requests'),
          ),
          if (isAdmin)
            const ButtonSegment(
              value: PrayerSegment.all,
              label: Text('All Requests'),
            ),
        ],
        selected: {segment},
        onSelectionChanged: (value) {
          ref.read(prayerSegmentProvider.notifier).state = value.first;
        },
      ),
    );
  }
}

enum PrayerSegment {
  my,
  all,
}

final prayerSegmentProvider =
    StateProvider<PrayerSegment>((ref) => PrayerSegment.my);
