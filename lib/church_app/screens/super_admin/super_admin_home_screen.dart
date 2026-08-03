import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/super_admin/create_church_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/learning_modules_admin_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/learning_results_admin_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/church_learning_setup_screen.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_application/church_app/services/super_admin/super_admin_church_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:intl/intl.dart';

const List<_FeatureToggleSpec> _superAdminFeatureSpecs = <_FeatureToggleSpec>[
  _FeatureToggleSpec(
    key: 'dashboardEnabled',
    labelKey: 'super_admin.feature_dashboard_short',
    icon: Icons.dashboard_customize_outlined,
    color: Colors.indigo,
  ),
  _FeatureToggleSpec(
    key: 'equipmentEnabled',
    labelKey: 'super_admin.feature_equipment',
    icon: Icons.inventory_2_outlined,
    color: Colors.teal,
  ),
  _FeatureToggleSpec(
    key: 'studioEnabled',
    labelKey: 'super_admin.feature_studio',
    icon: Icons.design_services_outlined,
    color: Colors.orange,
  ),
  _FeatureToggleSpec(
    key: 'membersEnabled',
    labelKey: 'super_admin.feature_members',
    icon: Icons.people_outline,
    color: Colors.blue,
  ),
  _FeatureToggleSpec(
    key: 'eventsEnabled',
    labelKey: 'super_admin.feature_events',
    icon: Icons.event_outlined,
    color: Colors.pink,
  ),
  _FeatureToggleSpec(
    key: 'globalFeedEnabled',
    labelKey: 'super_admin.feature_global_feed',
    icon: Icons.feed_outlined,
    color: Colors.green,
  ),
  _FeatureToggleSpec(
    key: 'bibleSwipeFetchEnabled',
    labelKey: 'super_admin.feature_bible_swipe',
    icon: Icons.menu_book_outlined,
    color: Colors.brown,
  ),
];

bool _isFeatureEnabled(AppConfig config, String key) {
  switch (key) {
    case 'dashboardEnabled':
      return config.dashboardEnabled;
    case 'equipmentEnabled':
      return config.equipmentEnabled;
    case 'studioEnabled':
      return config.studioEnabled;
    case 'membersEnabled':
      return config.membersEnabled;
    case 'eventsEnabled':
      return config.eventsEnabled;
    case 'globalFeedEnabled':
      return config.globalFeedEnabled;
    case 'bibleSwipeFetchEnabled':
      return config.bibleSwipeFetchEnabled;
    default:
      return false;
  }
}

final superAdminFeedbackProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return FirestorePaths.globalFeedbackCollection(firestore)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

class SuperAdminHomeScreen extends ConsumerStatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  ConsumerState<SuperAdminHomeScreen> createState() =>
      _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends ConsumerState<SuperAdminHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseAnalytics.instance.logEvent(
        name: 'super_admin_dashboard_opened',
      );
    });
  }

  Future<void> _openNormalFlow(BuildContext context) async {
    ref.read(forcePreflowThemeProvider.notifier).state = true;
    ref.read(selectedChurchProvider.notifier).state = null;
    ref.invalidate(currentChurchIdProvider);
    await ref.read(superAdminEntryModeProvider.notifier).setMode(
          SuperAdminEntryMode.normal,
        );
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const SelectChurchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final churchesAsync = ref.watch(allChurchesProvider);
    final feedbackAsync = ref.watch(superAdminFeedbackProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('super_admin.title'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: context.t('super_admin.back_to_normal_flow'),
            onPressed: () async => _openNormalFlow(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ],
      ),
      body: LinearScreenBackground(
        solidBackground: true,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: churchesAsync.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      '${context.t('common.error_prefix')}: $error',
                    ),
                  ),
                  data: (churches) {
                    final filteredChurches = churches.where((church) {
                      final query = _query.trim().toLowerCase();
                      if (query.isEmpty) return true;
                      return church.name.toLowerCase().contains(query) ||
                          church.id.toLowerCase().contains(query) ||
                          church.pastorName.toLowerCase().contains(query);
                    }).toList(growable: false);
                    final pendingChurches = filteredChurches
                        .where((church) => !church.enabled)
                        .toList(growable: false);
                    final approvedChurches = filteredChurches
                        .where((church) => church.enabled)
                        .toList(growable: false);

                    return DefaultTabController(
                      length: 3,
                      child: NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) {
                          return [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                child: Column(
                                  children: [
                                    Container(
                                      decoration:
                                          carouselBoxDecoration(context),
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.t('super_admin.title'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            context.t('super_admin.subtitle'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            child: SolidButton(
                                              label: context.t(
                                                  'super_admin.create_church'),
                                              onPressed: () async {
                                                final createResult =
                                                    await Navigator.of(context)
                                                        .push<String>(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const CreateChurchScreen(),
                                                  ),
                                                );
                                                if (createResult == null ||
                                                    !context.mounted) {
                                                  return;
                                                }
                                                FirebaseAnalytics.instance
                                                    .logEvent(
                                                  name:
                                                      'church_created_super_admin',
                                                  parameters: {
                                                    'result': createResult,
                                                  },
                                                );
                                                final snackText =
                                                    switch (createResult) {
                                                  'created_with_email' =>
                                                    context.t(
                                                        'super_admin.create_success'),
                                                  'created_email_failed' =>
                                                    context.t(
                                                        'super_admin.create_success_email_failed'),
                                                  _ => context.t(
                                                      'super_admin.create_success_no_account'),
                                                };
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(snackText),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LearningModulesAdminScreen(),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.school_outlined,
                                              ),
                                              label: Text(
                                                context.t(
                                                  'learning.super_admin_action',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            context.t(
                                              'learning.super_admin_action_hint',
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FeatureOverviewPanel(churches: churches),
                                    const SizedBox(height: 16),
                                    Container(
                                      decoration:
                                          carouselBoxDecoration(context),
                                      padding: const EdgeInsets.all(16),
                                      child: AppTextField(
                                        variant: AppTextFieldVariant.search,
                                        controller: _searchController,
                                        onChanged: (value) {
                                          setState(() {
                                            _query = value;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: context
                                              .t('super_admin.search_hint'),
                                          prefixIcon: const Icon(Icons.search),
                                          suffixIcon: _query.isEmpty
                                              ? null
                                              : IconButton(
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {
                                                      _query = '';
                                                    });
                                                  },
                                                  icon: const Icon(Icons.clear),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabBarHeaderDelegate(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Container(
                                    decoration: carouselBoxDecoration(context),
                                    padding: const EdgeInsets.all(6),
                                    child: Builder(
                                      builder: (context) {
                                        final theme = Theme.of(context);
                                        final colorScheme = theme.colorScheme;
                                        final isDark =
                                            theme.brightness == Brightness.dark;

                                        return TabBar(
                                          dividerColor: Colors.transparent,
                                          labelColor: Colors.white,
                                          unselectedLabelColor: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.74)
                                              : colorScheme.onSurface
                                                  .withValues(alpha: 0.74),
                                          indicator: BoxDecoration(
                                            color: colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          indicatorSize:
                                              TabBarIndicatorSize.tab,
                                          labelStyle: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                          unselectedLabelStyle: theme
                                              .textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                          tabs: [
                                            Tab(
                                              text:
                                                  'Not Approved (${pendingChurches.length})',
                                            ),
                                            Tab(
                                              text:
                                                  'Approved (${approvedChurches.length})',
                                            ),
                                            Tab(
                                              text:
                                                  'Feedback (${feedbackAsync.maybeWhen(data: (items) => items.length, orElse: () => 0)})',
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          children: [
                            _ChurchListTab(
                              churches: pendingChurches,
                              emptyMessage: context
                                  .t('super_admin.pending_section_empty'),
                            ),
                            _ChurchListTab(
                              churches: approvedChurches,
                              emptyMessage: context
                                  .t('super_admin.approved_section_empty'),
                            ),
                            _FeedbackListTab(feedbackAsync: feedbackAsync),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuperAdminChurchTile extends ConsumerWidget {
  const _SuperAdminChurchTile({
    required this.church,
  });

  final Church church;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(churchAppConfigProvider(church.id)).asData?.value;

    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChurchLogoAvatar(
                logo: church.logo,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      church.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      church.id,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (church.pastorName.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        church.pastorName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: church.enabled,
                onChanged: (value) async {
                  await SuperAdminChurchService(
                    ref.read(firestoreProvider),
                  ).updateChurchEnabled(
                    churchId: church.id,
                    enabled: value,
                  );
                  FirebaseAnalytics.instance.logEvent(
                    name: 'church_status_changed',
                    parameters: {
                      'church_id': church.id,
                      'enabled': value.toString(),
                    },
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.t('super_admin.status_updated'),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (config != null) ...[
            const SizedBox(height: 14),
            _FeatureToggleGrid(church: church, config: config),
          ],
          if (church.email.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              church.email,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChurchLearningSetupScreen(
                    church: church,
                    repository: LearningModuleRepository(
                      firestore: ref.read(firestoreProvider),
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.school_outlined),
              label: Text(context.t('learning.setup_action')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LearningResultsAdminScreen(
                    church: church,
                    repository: LearningModuleRepository(
                      firestore: ref.read(firestoreProvider),
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.insights_outlined),
              label: Text(context.t('learning.results_action')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CreateChurchScreen(church: church),
                  ),
                );
                if (updated != true || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.t('super_admin.edit_success'),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                context.t('super_admin.edit_church'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchListTab extends StatelessWidget {
  const _ChurchListTab({
    required this.churches,
    required this.emptyMessage,
  });

  final List<Church> churches;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (churches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            decoration: carouselBoxDecoration(context),
            padding: const EdgeInsets.all(18),
            child: Text(emptyMessage),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: churches.length,
      itemBuilder: (context, index) {
        final church = churches[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SuperAdminChurchTile(church: church),
        );
      },
    );
  }
}

class _FeedbackListTab extends ConsumerWidget {
  const _FeedbackListTab({required this.feedbackAsync});

  final AsyncValue<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      feedbackAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return feedbackAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text(
          '${context.t('common.error_prefix')}: $error',
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Container(
                decoration: carouselBoxDecoration(context),
                padding: const EdgeInsets.all(18),
                child: Text(context.t(
                    'ui.super_admin_home.no_feedback_has_been_submitted_yet')),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final doc = items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey('feedback-${doc.id}'),
                direction: DismissDirection.endToStart,
                background: const _FeedbackDeleteBackground(),
                confirmDismiss: (_) => _confirmDeleteFeedback(context, doc),
                onDismissed: (_) async {
                  await doc.reference.delete();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            context.t('ui.super_admin_home.feedback_deleted'))),
                  );
                },
                child: _FeedbackTile(doc: doc),
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedbackTile extends ConsumerWidget {
  const _FeedbackTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data();
    final theme = Theme.of(context);
    final status = (data['status'] ?? 'new').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final message = (data['message'] ?? '').toString().trim();
    final userName = (data['userName'] ?? '').toString().trim();
    final userEmail = (data['userEmail'] ?? '').toString().trim();
    final userPhone = (data['userPhone'] ?? '').toString().trim();
    final userRole = (data['userRole'] ?? '').toString().trim();
    final churchName = (data['churchName'] ?? '').toString().trim();
    final churchId = (data['churchId'] ?? '').toString().trim();

    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName.isEmpty ? 'Anonymous user' : userName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (userEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(userEmail, style: theme.textTheme.bodySmall),
                    ],
                    if (userPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(userPhone, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              _FeedbackStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message.isEmpty ? '-' : message,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (churchName.isNotEmpty || churchId.isNotEmpty)
                _FeedbackMetaChip(
                  icon: Icons.account_balance_outlined,
                  label: churchName.isNotEmpty ? churchName : churchId,
                ),
              if (createdAt != null)
                _FeedbackMetaChip(
                  icon: Icons.schedule_outlined,
                  label: DateFormat('d MMM yyyy, h:mm a').format(createdAt),
                ),
              if (userRole.isNotEmpty)
                _FeedbackMetaChip(
                  icon: Icons.verified_user_outlined,
                  label: userRole,
                ),
            ],
          ),
          if (status != 'reviewed') ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await doc.reference.set(
                    {
                      'status': 'reviewed',
                      'reviewedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    },
                    SetOptions(merge: true),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.t(
                            'ui.super_admin_home.feedback_marked_reviewed'))),
                  );
                },
                icon: const Icon(Icons.done_rounded),
                label: Text(context.t('ui.super_admin_home.mark_reviewed')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackDeleteBackground extends StatelessWidget {
  const _FeedbackDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

Future<bool?> _confirmDeleteFeedback(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final userName = (data['userName'] ?? '').toString().trim();
  final message = (data['message'] ?? '').toString().trim();

  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.t('ui.super_admin_home.delete_feedback')),
        content: Text(
          [
            if (userName.isNotEmpty) 'From: $userName',
            if (message.isNotEmpty) message,
            'This cannot be undone.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.t('ui.super_admin_home.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.t('ui.super_admin_home.delete')),
          ),
        ],
      );
    },
  );
}

class _FeedbackStatusChip extends StatelessWidget {
  const _FeedbackStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final reviewed = status == 'reviewed';
    final color = reviewed ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reviewed ? 'Reviewed' : 'New',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _FeedbackMetaChip extends StatelessWidget {
  const _FeedbackMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class _FeatureOverviewPanel extends ConsumerWidget {
  const _FeatureOverviewPanel({required this.churches});

  final List<Church> churches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = churches
        .map(
          (church) =>
              ref.watch(churchAppConfigProvider(church.id)).asData?.value,
        )
        .whereType<AppConfig>()
        .toList(growable: false);
    final dashboardCount =
        configs.where((config) => config.dashboardEnabled).length;
    final equipmentCount =
        configs.where((config) => config.equipmentEnabled).length;
    final studioCount = configs.where((config) => config.studioEnabled).length;

    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('ui.super_admin_home.feature_map'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
                'ui.super_admin_home.quick_view_of_which_modules_are_enabled_across_churches'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureStatChip(
                label: context.t('super_admin.feature_dashboard_short'),
                count: dashboardCount,
                total: churches.length,
                icon: Icons.dashboard_customize_outlined,
                color: Colors.indigo,
              ),
              _FeatureStatChip(
                label: context.t('super_admin.feature_equipment'),
                count: equipmentCount,
                total: churches.length,
                icon: Icons.inventory_2_outlined,
                color: Colors.teal,
              ),
              _FeatureStatChip(
                label: context.t('super_admin.feature_studio'),
                count: studioCount,
                total: churches.length,
                icon: Icons.design_services_outlined,
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureToggleGrid extends ConsumerWidget {
  const _FeatureToggleGrid({
    required this.church,
    required this.config,
  });

  final Church church;
  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _superAdminFeatureSpecs
          .map(
            (item) => _FeatureToggleChip(
              churchId: church.id,
              item: item,
              enabled: _isFeatureEnabled(config, item.key),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _FeatureStatChip extends StatelessWidget {
  const _FeatureStatChip({
    required this.label,
    required this.count,
    required this.total,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            '$count / $total',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeatureToggleChip extends ConsumerWidget {
  const _FeatureToggleChip({
    required this.churchId,
    required this.item,
    required this.enabled,
  });

  final String churchId;
  final _FeatureToggleSpec item;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: enabled
          ? item.color.withValues(alpha: 0.12)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final nextValue = !enabled;
          await SuperAdminChurchService(
            ref.read(firestoreProvider),
          ).updateChurchFeature(
            churchId: churchId,
            featureKey: item.key,
            enabled: nextValue,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t(
                  'super_admin.feature_updated',
                  parameters: {'feature': context.t(item.labelKey)},
                ),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 18,
                color: enabled ? item.color : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 8),
              Text(
                context.t(item.labelKey),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: enabled
                          ? item.color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(
                enabled
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                size: 18,
                color: enabled ? item.color : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureToggleSpec {
  const _FeatureToggleSpec({
    required this.key,
    required this.labelKey,
    required this.icon,
    required this.color,
  });

  final String key;
  final String labelKey;
  final IconData icon;
  final Color color;
}
