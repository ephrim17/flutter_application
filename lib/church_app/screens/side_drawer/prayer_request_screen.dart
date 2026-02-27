import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:intl/intl.dart';

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
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddPrayerModal(),
          );
        },
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
                  title: Text(prayer.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer.description),
                      const SizedBox(height: 8),

                      /// Show user only if NOT anonymous
                      if (!prayer.isAnonymous)
                        ref.watch(churchUserNameProvider(prayer.userId)).when(
                              loading: () =>
                                  const Text("By: Loading..."),
                              error: (_, __) =>
                                  const Text("By: Unknowns"),
                              data: (name) => Text(
                                  "By: ${name?.toUpperCase() ?? "Unknown"}"),
                            ),

                      const SizedBox(height: 6),

                      Text(
                        "Expires: ${DateFormat.yMMMd().format(prayer.expiryDate)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (segment == PrayerSegment.my)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) =>
                                AddPrayerModal(existing: prayer),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () async {
                          await ref
                              .read(prayerRepositoryProvider)
                              .deletePrayer(prayer.id);
                        },
                      ),
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

class AddPrayerModal extends ConsumerStatefulWidget {
  final PrayerRequest? existing;
  const AddPrayerModal({super.key, this.existing});

  @override
  ConsumerState<AddPrayerModal> createState() =>
      _AddPrayerModalState();
}

class _AddPrayerModalState
    extends ConsumerState<AddPrayerModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  bool _isAnonymous = false;
  DateTime? _expiryDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.title;
      _descCtrl.text = widget.existing!.description;
      _isAnonymous = widget.existing!.isAnonymous;
      _expiryDate = widget.existing!.expiryDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              "Prayer Request",
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? "Title required"
                      : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? "Description required"
                      : null,
            ),

            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text("Submit anonymously"),
              value: _isAnonymous,
              onChanged: (v) {
                setState(() => _isAnonymous = v);
              },
            ),

            const SizedBox(height: 8),

            ListTile(
              title: Text(
                _expiryDate == null
                    ? "Select expiry date"
                    : "Expiry: ${DateFormat.yMMMd().format(_expiryDate!)}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate:
                      now.add(const Duration(days: 30)),
                );

                if (picked != null) {
                  setState(() => _expiryDate = picked);
                }
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Submit"),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select expiry date")),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (widget.existing == null) {
      await ref.read(prayerRepositoryProvider).addPrayer(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            isAnonymous: _isAnonymous,
            expiryDate: _expiryDate!,
          );
    } else {
      await ref.read(prayerRepositoryProvider).updatePrayer(
            prayerId: widget.existing!.id,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            isAnonymous: _isAnonymous,
            expiryDate: _expiryDate!,
          );
    }

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Prayer request saved successfully"),
      ),
    );
  }
}
