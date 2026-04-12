import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class PrayerRequestScreen extends ConsumerStatefulWidget {
  const PrayerRequestScreen({super.key});

  @override
  ConsumerState<PrayerRequestScreen> createState() =>
      _PrayerRequestScreenState();
}

class _PrayerRequestScreenState extends ConsumerState<PrayerRequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await logChurchAnalyticsEvent(
        ref,
        name: 'prayer_screen_opened',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final segment = ref.watch(prayerSegmentProvider);

    final prayersAsync = segment == PrayerSegment.my
        ? ref.watch(myPrayerRequestsProvider)
        : ref.watch(allPrayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
            text: segment == PrayerSegment.my
                ? context.t(
                    'prayer.my_requests_title',
                    fallback: 'My Prayer Requests',
                  )
                : context.t(
                    'prayer.all_requests_title',
                    fallback: 'All Prayer Requests',
                  )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _SegmentControl(isAdmin: isAdmin),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await logChurchAnalyticsEvent(
            ref,
            name: 'prayer_request_create_started',
            parameters: {
              'segment': segment.name,
            },
          );
          showAppModalBottomSheet(
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
            return Center(
              child: Text(
                context.t('prayer.none', fallback: 'No prayer requests yet'),
              ),
            );
          }

          return ListView.builder(
            itemCount: prayers.length,
            itemBuilder: (_, i) {
              final prayer = prayers[i];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  onTap: () async {
                    await logChurchAnalyticsEvent(
                      ref,
                      name: 'prayer_request_opened',
                      parameters: {
                        'prayer_id': prayer.id,
                        'segment': segment.name,
                        'is_anonymous': prayer.isAnonymous,
                      },
                    );
                    if (!context.mounted) return;
                    await _showPrayerDetailsSheet(context, prayer);
                  },
                  title: Text(prayer.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer.description),
                      const SizedBox(height: 8),

                      /// Show user only if NOT anonymous
                      if (!prayer.isAnonymous)
                        ref.watch(churchUserNameProvider(prayer.userId)).when(
                              loading: () => Text(
                                context.t(
                                  'prayer.by_loading',
                                  fallback: 'By: Loading...',
                                ),
                              ),
                              error: (_, __) => Text(
                                context.t(
                                  'prayer.by_unknown',
                                  fallback: 'By: Unknown',
                                ),
                              ),
                              data: (name) => Text(
                                  "By: ${name?.toUpperCase() ?? "Unknown"}"),
                            ),

                      const SizedBox(height: 6),

                      Text(
                        "${context.t('prayer.expires_prefix', fallback: 'Expires')}: ${DateFormat.yMMMd().format(prayer.expiryDate)}",
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
                          onPressed: () async {
                            await logChurchAnalyticsEvent(
                              ref,
                              name: 'prayer_request_edit_started',
                              parameters: {
                                'prayer_id': prayer.id,
                                'segment': segment.name,
                              },
                            );
                            showAppModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => AddPrayerModal(existing: prayer),
                            );
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await ref
                              .read(prayerRepositoryProvider)
                              .deletePrayer(prayer.id);
                          await logChurchAnalyticsEvent(
                            ref,
                            name: 'prayer_request_deleted',
                            parameters: {
                              'prayer_id': prayer.id,
                              'segment': segment.name,
                            },
                          );
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

Future<void> _showPrayerDetailsSheet(
  BuildContext context,
  PrayerRequest prayer,
) {
  return showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prayer.title.trim().isEmpty ? 'Prayer Request' : prayer.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              prayer.description.trim().isEmpty
                  ? 'No description provided.'
                  : prayer.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Text(
              'Expires: ${DateFormat.yMMMd().format(prayer.expiryDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
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
          ButtonSegment(
            value: PrayerSegment.my,
            label: Text(
              context.t('prayer.my_requests_tab', fallback: 'My Requests'),
            ),
          ),
          if (isAdmin)
            ButtonSegment(
              value: PrayerSegment.all,
              label: Text(
                context.t('prayer.all_requests_tab', fallback: 'All Requests'),
              ),
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
  ConsumerState<AddPrayerModal> createState() => _AddPrayerModalState();
}

class _AddPrayerModalState extends ConsumerState<AddPrayerModal> {
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
            Text(
              context.t('prayer.modal_title', fallback: 'Prayer Request'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: context.t('prayer.title_label', fallback: 'Title'),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t('prayer.title_required',
                      fallback: 'Title required')
                  : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.t(
                  'prayer.description_label',
                  fallback: 'Description',
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.t(
                      'prayer.description_required',
                      fallback: 'Description required',
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                context.t(
                  'prayer.submit_anonymous',
                  fallback: 'Submit anonymously',
                ),
              ),
              value: _isAnonymous,
              onChanged: (v) {
                setState(() => _isAnonymous = v);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                _expiryDate == null
                    ? context.t(
                        'prayer.select_expiry_date',
                        fallback: 'Select expiry date',
                      )
                    : "${context.t('prayer.expiry_prefix', fallback: 'Expiry')}: ${DateFormat.yMMMd().format(_expiryDate!)}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 30)),
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
                  : Text(
                      context.t('common.submit', fallback: 'Submit'),
                    ),
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
        SnackBar(
            content: Text(
          context.t(
            'prayer.select_expiry_required',
            fallback: 'Please select expiry date',
          ),
        )),
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentChurchId = await ref.read(currentChurchIdProvider.future);

    if (widget.existing == null) {
      await ref.read(prayerRepositoryProvider).addPrayer(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            isAnonymous: _isAnonymous,
            expiryDate: _expiryDate!,
          );
      await FirebaseAnalytics.instance.logEvent(
        name: 'prayer_request_created',
        parameters: {
          if (currentChurchId != null && currentChurchId.trim().isNotEmpty)
            'church_id': currentChurchId,
          'is_anonymous': _isAnonymous.toString(),
        },
      );
    } else {
      await ref.read(prayerRepositoryProvider).updatePrayer(
            prayerId: widget.existing!.id,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            isAnonymous: _isAnonymous,
            expiryDate: _expiryDate!,
          );
      await FirebaseAnalytics.instance.logEvent(
        name: 'prayer_request_updated',
        parameters: {
          if (currentChurchId != null && currentChurchId.trim().isNotEmpty)
            'church_id': currentChurchId,
          'prayer_id': widget.existing!.id,
          'is_anonymous': _isAnonymous.toString(),
        },
      );
    }

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'prayer.saved_success',
            fallback: 'Prayer request saved successfully',
          ),
        ),
      ),
    );
  }
}
