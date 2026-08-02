import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/bible_swipe_verse_model.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/for_you_section_config_model.dart';
import 'package:flutter_application/church_app/models/home_section_models/home_section_config_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart'
    show firebaseAuthProvider;
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_book_repository.dart';
import 'package:flutter_application/church_app/services/faith_engagement_repository.dart';
import 'package:flutter_application/church_app/services/studio/studio_repository.dart';
import 'package:flutter_application/church_app/screens/side_drawer/faith_engagement_studio_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/admin_email_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/bible_verse_picker_sheet.dart';

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await logChurchAnalyticsEvent(
        ref,
        name: 'studio_opened',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final churchIdAsync = ref.watch(currentChurchIdProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.t('studio.title'))),
        body: Center(
          child: Text(ref.t('studio.admin_only')),
        ),
      );
    }

    return churchIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(ref.t('studio.title'))),
        body: Center(child: Text('${ref.t('common.error_prefix')}: $error')),
      ),
      data: (churchId) {
        if (churchId == null) {
          return Scaffold(
            appBar: AppBar(title: Text(ref.t('studio.title'))),
            body: Center(child: Text(ref.t('studio.no_church_selected'))),
          );
        }

        final repository = StudioRepository(
          firestore: ref.read(firestoreProvider),
          auth: ref.read(firebaseAuthProvider),
          churchId: churchId,
        );
        final configAsync = ref.watch(appConfigProvider);
        final config = configAsync.asData?.value;

        final categories = <_StudioCategory>[
          _StudioCategory(
            title: context.t('ui.studio.brand_identity'),
            subtitle:
                context.t('ui.studio.shape_the_look_and_core_church_profile'),
            items: [
              _StudioToolItem(
                title: ref.t('studio.tab_theme'),
                subtitle:
                    context.t('ui.studio.update_colors_and_visual_branding'),
                icon: Icons.palette_outlined,
                status: _StudioToolStatus(
                  label: context.t('ui.studio.theme'),
                  tone: _StudioStatusTone.neutral,
                ),
                builder: (_) => _ThemeEditor(
                  onSave: ({
                    required primaryColor,
                    required secondaryColor,
                  }) {
                    return repository.updateThemeColors(
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    );
                  },
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_about'),
                subtitle: context
                    .t('ui.studio.edit_church_name_mission_values_and_story'),
                icon: Icons.auto_stories_outlined,
                status: _StudioToolStatus(
                  label: context.t('ui.studio.profile'),
                  tone: _StudioStatusTone.neutral,
                ),
                builder: (_) => _AboutEditor(repository: repository),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_pastor'),
                subtitle: context
                    .t('ui.studio.manage_pastor_entries_and_contact_details'),
                icon: Icons.person_outline_rounded,
                countStream:
                    repository.watchPastors().map((docs) => docs.length),
                builder: (screenContext) => _CollectionEditor(
                  stream: repository.watchPastors(),
                  addLabel: ref.t('studio.add_pastor'),
                  emptyText: ref.t('studio.no_pastors'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) => (data['contact'] ?? '') as String,
                  onAdd: () => _showPastorEditor(screenContext, repository),
                  onEdit: (doc) => _showPastorEditor(
                    screenContext,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deletePastor(
                    doc.id,
                    imageUrl: (doc.data()['imageUrl'] ?? '') as String,
                  ),
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_footer'),
                subtitle: context
                    .t('ui.studio.edit_footer_contacts_and_social_links'),
                icon: Icons.view_day_outlined,
                status: _StudioToolStatus(
                  label: context.t('ui.studio.links'),
                  tone: _StudioStatusTone.neutral,
                ),
                builder: (_) => _FooterEditor(repository: repository),
              ),
            ],
          ),
          _StudioCategory(
            title: context.t('ui.studio.content_worship'),
            subtitle: context
                .t('ui.studio.manage_posts_readings_and_devotional_content'),
            items: [
              _StudioToolItem(
                title: ref.t('studio.tab_announcements'),
                subtitle: context.t(
                    'ui.studio.publish_important_updates_with_optional_images'),
                icon: Icons.campaign_outlined,
                countStream:
                    repository.watchAnnouncements().map((docs) => docs.length),
                builder: (screenContext) => _CollectionEditor(
                  stream: repository.watchAnnouncements(),
                  addLabel: ref.t('studio.add_announcement'),
                  emptyText: ref.t('studio.no_announcements'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileStatus: (data) {
                    final expiryAt = (data['expiryAt'] as Timestamp?)?.toDate();
                    if (expiryAt == null || expiryAt.isAfter(DateTime.now())) {
                      return null;
                    }

                    return _StudioInlineStatusChip(
                      label: context.t('ui.studio.expired'),
                      color: Colors.deepOrange,
                    );
                  },
                  tileSubtitle: (data) =>
                      '${ref.t('studio.announcement_priority_prefix')}: ${data['priority'] ?? 0}\n${data['body'] ?? ''}',
                  onAdd: () =>
                      _showAnnouncementEditor(screenContext, repository),
                  onEdit: (doc) => _showAnnouncementEditor(
                    screenContext,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteAnnouncement(
                    doc.id,
                    imageUrl: (doc.data()['imageUrl'] ?? '') as String,
                  ),
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_events'),
                subtitle:
                    context.t('ui.studio.create_and_organize_church_events'),
                icon: Icons.event_outlined,
                countStream:
                    repository.watchEvents().map((docs) => docs.length),
                builder: (screenContext) => _CollectionEditor(
                  stream: repository.watchEvents(),
                  addLabel: ref.t('studio.add_event'),
                  emptyText: ref.t('studio.no_events'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileStatus: (data) {
                    final expiryAt = (data['expiryAt'] as Timestamp?)?.toDate();
                    if (expiryAt == null || expiryAt.isAfter(DateTime.now())) {
                      return null;
                    }

                    return _StudioInlineStatusChip(
                      label: context.t('ui.studio.expired_a689'),
                      color: Colors.deepOrange,
                    );
                  },
                  tileSubtitle: (data) {
                    final parts = <String>[
                      if ((data['timing'] ?? '').toString().isNotEmpty)
                        (data['timing'] ?? '').toString(),
                      if ((data['type'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_type_prefix')}: ${data['type']}',
                      if ((data['contact'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_contact_prefix')}: ${data['contact']}',
                      if ((data['location'] ?? '').toString().isNotEmpty)
                        '${ref.t('studio.event_location_prefix')}: ${data['location']}',
                      if (data['isRecurring'] == true &&
                          (data['recurrenceFrequency'] ?? '').toString() ==
                              'weekly')
                        'Repeats weekly',
                    ];
                    return parts.join('\n');
                  },
                  onAdd: () => _showEventEditor(screenContext, repository),
                  onEdit: (doc) => _showEventEditor(
                    screenContext,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteEvent(doc.id),
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_articles'),
                subtitle: context
                    .t('ui.studio.publish_long_form_inspirational_content'),
                icon: Icons.article_outlined,
                countStream:
                    repository.watchArticles().map((docs) => docs.length),
                builder: (screenContext) => _CollectionEditor(
                  stream: repository.watchArticles(),
                  addLabel: ref.t('studio.add_article'),
                  emptyText: ref.t('studio.no_articles'),
                  tileTitle: (data) => (data['title'] ?? '') as String,
                  tileSubtitle: (data) => (data['description'] ?? '') as String,
                  onAdd: () => _showArticleEditor(screenContext, repository),
                  onEdit: (doc) => _showArticleEditor(
                    screenContext,
                    repository,
                    doc: doc,
                  ),
                  onDelete: (doc) => repository.deleteArticle(doc.id),
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_daily_verse'),
                subtitle: context
                    .t('ui.studio.set_the_verse_shown_to_members_each_day'),
                icon: Icons.menu_book_outlined,
                status: config == null
                    ? null
                    : _StudioToolStatus(
                        label: config.dailyVerseRef.book.trim().isEmpty
                            ? 'Not set'
                            : '${config.dailyVerseRef.book} ${config.dailyVerseRef.chapter}:${config.dailyVerseRef.verse}',
                        tone: config.dailyVerseRef.book.trim().isEmpty
                            ? _StudioStatusTone.neutral
                            : _StudioStatusTone.good,
                      ),
                builder: (_) => _ConfigVerseEditor(
                  title: ref.t('studio.tab_daily_verse'),
                  configSelector: (config) => config.dailyVerseRef,
                  onSave: ({required book, required chapter, required verse}) {
                    return repository.updateDailyVerse(
                      book: book,
                      chapter: chapter,
                      verse: verse,
                    );
                  },
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_promise'),
                subtitle:
                    context.t('ui.studio.manage_the_promise_word_reference'),
                icon: Icons.wb_sunny_outlined,
                status: config == null
                    ? null
                    : _StudioToolStatus(
                        label: config.promiseVerseRef.book.trim().isEmpty
                            ? 'Not set'
                            : '${config.promiseVerseRef.book} ${config.promiseVerseRef.chapter}:${config.promiseVerseRef.verse}',
                        tone: config.promiseVerseRef.book.trim().isEmpty
                            ? _StudioStatusTone.neutral
                            : _StudioStatusTone.good,
                      ),
                builder: (_) => _ConfigVerseEditor(
                  title: ref.t('studio.tab_promise'),
                  configSelector: (config) => config.promiseVerseRef,
                  onSave: ({required book, required chapter, required verse}) {
                    return repository.updatePromiseWord(
                      book: book,
                      chapter: chapter,
                      verse: verse,
                    );
                  },
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_bible_swipe'),
                subtitle: context.t(
                    'ui.studio.edit_verse_swipes_used_in_the_for_you_section'),
                icon: Icons.swipe_outlined,
                countStream: repository
                    .watchBibleSwipeVerses()
                    .map((items) => items.length),
                builder: (_) => _BibleSwipeVersesEditor(repository: repository),
              ),
            ],
          ),
          _StudioCategory(
            title: context.t('ui.studio.engagement'),
            subtitle: context
                .t('ui.studio.control_prompts_notifications_and_live_sections'),
            items: [
              _StudioToolItem(
                title: context.t('faith.studio_title'),
                subtitle: context.t('faith.engagement_studio_subtitle'),
                icon: Icons.diversity_3_outlined,
                builder: (_) => FaithEngagementStudioScreen(
                  repository: FaithEngagementRepository(
                    firestore: ref.read(firestoreProvider),
                    churchId: churchId,
                  ),
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_live_church'),
                subtitle: context.t(
                    'ui.studio.connect_a_youtube_channel_for_automatic_live_service'),
                icon: Icons.live_tv_outlined,
                countStream: repository.watchLiveChurchConfig().map(
                      (data) => data?['enabled'] == true ? 1 : 0,
                    ),
                builder: (_) => _LiveChurchEditor(repository: repository),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_sections'),
                subtitle: context.t(
                    'ui.studio.enable_disable_and_reorder_major_app_sections'),
                icon: Icons.dashboard_customize_outlined,
                status: _StudioToolStatus(
                  label: context.t('ui.studio.layout'),
                  tone: _StudioStatusTone.neutral,
                ),
                builder: (_) => _SectionsEditor(repository: repository),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_notifications'),
                subtitle: context
                    .t('ui.studio.queue_updates_to_church_or_topic_audiences'),
                icon: Icons.notifications_active_outlined,
                status: _StudioToolStatus(
                  label: context.t('ui.studio.broadcast'),
                  tone: _StudioStatusTone.neutral,
                ),
                builder: (_) => _NotificationComposer(
                  churchId: churchId,
                  onSend: ({required title, required body, required topic}) {
                    return repository.queueTopicNotification(
                      title: title,
                      body: body,
                      topic: topic,
                    );
                  },
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_prompt'),
                subtitle: context.t(
                    'ui.studio.configure_the_important_prompt_shown_to_users'),
                icon: Icons.priority_high_rounded,
                status: config == null
                    ? null
                    : _StudioToolStatus(
                        label: config.promptSheet.enabled ? 'Live' : 'Off',
                        tone: config.promptSheet.enabled
                            ? _StudioStatusTone.good
                            : _StudioStatusTone.neutral,
                      ),
                builder: (_) => _PromptSheetEditor(
                  onSave: ({
                    required title,
                    required desc,
                    required enabled,
                  }) {
                    return repository.updatePromptSheet(
                      title: title,
                      desc: desc,
                      enabled: enabled,
                    );
                  },
                ),
              ),
            ],
          ),
          _StudioCategory(
            title: context.t('ui.studio.admin_controls'),
            subtitle: context.t(
                'ui.studio.manage_access_and_church_wide_editing_permissions'),
            items: [
              _StudioToolItem(
                title: ref.t('studio.tab_admin_mode'),
                subtitle: context.t(
                    'ui.studio.pause_the_app_for_regular_users_while_work_is_in_pro'),
                icon: Icons.construction_outlined,
                status: config == null
                    ? null
                    : _StudioToolStatus(
                        label: config.adminMode.enabled ? 'On' : 'Off',
                        tone: config.adminMode.enabled
                            ? _StudioStatusTone.good
                            : _StudioStatusTone.neutral,
                      ),
                builder: (_) => _AdminModeEditor(
                  onSave: ({
                    required enabled,
                  }) {
                    return repository.updateAdminMode(
                      enabled: enabled,
                    );
                  },
                ),
              ),
              _StudioToolItem(
                title: ref.t('studio.tab_admins'),
                subtitle: context
                    .t('ui.studio.update_the_list_of_admin_email_addresses'),
                icon: Icons.admin_panel_settings_outlined,
                status: config == null
                    ? null
                    : _StudioToolStatus(
                        label: context.t(
                          'studio.admin_count',
                          parameters: {'count': '${config.admins.length}'},
                        ),
                        tone: _StudioStatusTone.neutral,
                      ),
                builder: (_) => _AdminsEditor(
                  onSave: repository.updateAdmins,
                ),
              ),
            ],
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(ref.t('studio.title')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _StudioOverviewCard(
                title: ref.t('studio.title'),
                subtitle: context.t(
                    'ui.studio.manage_branding_content_engagement_and_admin_control'),
              ),
              const SizedBox(height: 18),
              for (final category in categories) ...[
                _StudioCategorySection(category: category),
                const SizedBox(height: 18),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StudioOverviewCard extends StatelessWidget {
  const _StudioOverviewCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: welcomeBackCardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.space_dashboard_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioCategorySection extends StatelessWidget {
  const _StudioCategorySection({
    required this.category,
  });

  final _StudioCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...category.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudioToolCard(item: item),
            )),
      ],
    );
  }
}

class _StudioToolCard extends ConsumerWidget {
  const _StudioToolCard({
    required this.item,
  });

  final _StudioToolItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: () async {
        await logChurchAnalyticsEvent(
          ref,
          name: 'studio_option_selected',
          parameters: {
            'option': item.title,
          },
        );
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _StudioToolScreen(
              item: item,
            ),
          ),
        );
      },
      child: Ink(
        decoration: carouselBoxDecoration(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (item.status != null) ...[
                          const SizedBox(width: 8),
                          _StudioStatusPill(status: item.status!),
                        ],
                        if (item.countStream != null)
                          StreamBuilder<int>(
                            stream: item.countStream,
                            builder: (context, snapshot) {
                              final count = snapshot.data;
                              if (count == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _StudioCountPill(count: count),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioToolScreen extends StatelessWidget {
  const _StudioToolScreen({
    required this.item,
  });

  final _StudioToolItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 54),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      disabledBackgroundColor:
          theme.colorScheme.primary.withValues(alpha: 0.42),
      disabledForegroundColor:
          theme.colorScheme.onPrimary.withValues(alpha: 0.92),
    );

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: Theme(
        data: theme.copyWith(
          filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
        ),
        child: SafeArea(
          top: false,
          child: item.builder(context),
        ),
      ),
    );
  }
}

class _StudioCategory {
  const _StudioCategory({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_StudioToolItem> items;
}

class _StudioToolItem {
  const _StudioToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.status,
    this.countStream,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext context) builder;
  final _StudioToolStatus? status;
  final Stream<int>? countStream;
}

class _StudioToolStatus {
  const _StudioToolStatus({
    required this.label,
    required this.tone,
  });

  final String label;
  final _StudioStatusTone tone;
}

enum _StudioStatusTone {
  neutral,
  good,
}

class _StudioStatusPill extends StatelessWidget {
  const _StudioStatusPill({
    required this.status,
  });

  final _StudioToolStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = status.tone == _StudioStatusTone.good
        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
        : theme.colorScheme.primary.withValues(alpha: 0.10);
    final foregroundColor = status.tone == _StudioStatusTone.good
        ? const Color(0xFF15803D)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudioCountPill extends StatelessWidget {
  const _StudioCountPill({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CollectionEditor extends StatelessWidget {
  const _CollectionEditor({
    required this.stream,
    required this.addLabel,
    required this.emptyText,
    required this.tileTitle,
    required this.tileSubtitle,
    this.tileStatus,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final String addLabel;
  final String emptyText;
  final String Function(Map<String, dynamic>) tileTitle;
  final String Function(Map<String, dynamic>) tileSubtitle;
  final Widget? Function(Map<String, dynamic>)? tileStatus;
  final Future<void> Function() onAdd;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      initialData: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child:
                Text('${context.t('common.error_prefix')}: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(addLabel),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(child: Text(emptyText)),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(addLabel),
                ),
              );
            }

            final doc = docs[index - 1];
            final data = doc.data();
            final subtitle = tileSubtitle(data);

            return Container(
              decoration: carouselBoxDecoration(context),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(tileTitle(data)),
                    ),
                    if (tileStatus != null) ...[
                      const SizedBox(width: 8),
                      if (tileStatus!(data) case final statusWidget?)
                        statusWidget,
                    ],
                  ],
                ),
                subtitle: Text(subtitle),
                isThreeLine: subtitle.contains('\n'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: AppBarTitle(
                              text: context.t('studio.delete_title'),
                            ),
                            content: Text(
                              '${context.t('studio.delete_confirm_remove_prefix')} "${tileTitle(data)}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(context.t('settings.cancel')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(context.t('common.delete')),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          if (!context.mounted) return;
                          await _runWithBlockingLoader(
                            context,
                            () => onDelete(doc),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StudioInlineStatusChip extends StatelessWidget {
  const _StudioInlineStatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ConfigVerseEditor extends ConsumerWidget {
  const _ConfigVerseEditor({
    required this.title,
    required this.configSelector,
    required this.onSave,
  });

  final String title;
  final dynamic Function(AppConfig config) configSelector;
  final Future<void> Function({
    required String book,
    required int chapter,
    required int verse,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text('${context.t('common.error_prefix')}: $error'),
      ),
      data: (config) {
        final verseRef = configSelector(config);
        final versePreview = BibleRepository().getVerse(
          book: verseRef.book,
          chapter: verseRef.chapter,
          verse: verseRef.verse,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: carouselBoxDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                          'ui.studio.pick_the_exact_bible_verse_users_will_see_use_the_butto'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StudioInlineStatusChip(
                          label: verseRef.book,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _StudioInlineStatusChip(
                          label: context.t(
                            'studio.chapter_value',
                            parameters: {'chapter': '${verseRef.chapter}'},
                          ),
                          color: Colors.teal,
                        ),
                        _StudioInlineStatusChip(
                          label: context.t(
                            'studio.verse_value',
                            parameters: {'verse': '${verseRef.verse}'},
                          ),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Map<String, String>>(
                      future: versePreview,
                      builder: (context, snapshot) {
                        final verseText =
                            snapshot.data?['english'] ?? 'Loading verse...';
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verseText,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${verseRef.book} ${verseRef.chapter}:${verseRef.verse}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => showBibleVersePickerSheet(
                          context,
                          title: title,
                          initialBook: verseRef.book,
                          initialChapter: verseRef.chapter,
                          initialVerse: verseRef.verse,
                          onSave: onSave,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                            context.t('ui.studio.change_book_chapter_verse')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeEditor extends ConsumerWidget {
  const _ThemeEditor({
    required this.onSave,
  });

  final Future<void> Function({
    required String primaryColor,
    required String secondaryColor,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text(
          '${context.t('common.error_prefix')}: $error',
        ),
      ),
      data: (config) => _ThemeEditorForm(
        initialPrimaryColor: config.primaryColorHex,
        initialSecondaryColor: config.secondaryColorHex,
        onSave: onSave,
      ),
    );
  }
}

class _ThemeEditorForm extends StatefulWidget {
  const _ThemeEditorForm({
    required this.initialPrimaryColor,
    required this.initialSecondaryColor,
    required this.onSave,
  });

  final String initialPrimaryColor;
  final String initialSecondaryColor;
  final Future<void> Function({
    required String primaryColor,
    required String secondaryColor,
  }) onSave;

  @override
  State<_ThemeEditorForm> createState() => _ThemeEditorFormState();
}

class _ThemeEditorFormState extends State<_ThemeEditorForm> {
  late final TextEditingController _primaryController;
  late final TextEditingController _secondaryController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _primaryController =
        TextEditingController(text: widget.initialPrimaryColor);
    _secondaryController =
        TextEditingController(text: widget.initialSecondaryColor);
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  bool _isValidHex(String value) {
    return RegExp(r'^#([A-Fa-f0-9]{6})$').hasMatch(value.trim());
  }

  String _normalizeHex(String value) => value.trim().toUpperCase();

  String _colorToHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Color _safeColor(String value) {
    final normalized = _normalizeHex(value);
    if (_isValidHex(normalized)) {
      return normalized.toColor();
    }
    return Colors.grey.shade400;
  }

  Future<void> _pickColor({
    required TextEditingController controller,
    required String label,
  }) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => _ThemeColorPickerDialog(
        title: label,
        initialColor: _safeColor(controller.text),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _colorToHex(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: carouselBoxDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.theme_hint'),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('studio.theme_palette_hint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _ThemeColorField(
                  label: context.t('studio.theme_primary_label'),
                  controller: _primaryController,
                  previewColor: _safeColor(_primaryController.text),
                  onChanged: (_) => setState(() {}),
                  onPickPressed: () => _pickColor(
                    controller: _primaryController,
                    label: context.t('studio.theme_primary_label'),
                  ),
                ),
                const SizedBox(height: 16),
                _ThemeColorField(
                  label: context.t('studio.theme_secondary_label'),
                  controller: _secondaryController,
                  previewColor: _safeColor(_secondaryController.text),
                  onChanged: (_) => setState(() {}),
                  onPickPressed: () => _pickColor(
                    controller: _secondaryController,
                    label: context.t('studio.theme_secondary_label'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final primary =
                                _normalizeHex(_primaryController.text);
                            final secondary =
                                _normalizeHex(_secondaryController.text);
                            if (!_isValidHex(primary) ||
                                !_isValidHex(secondary)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.theme_invalid_hex'),
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _isSaving = true);
                            try {
                              await widget.onSave(
                                primaryColor: primary,
                                secondaryColor: secondary,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.theme_updated'),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeColorField extends StatelessWidget {
  const _ThemeColorField({
    required this.label,
    required this.controller,
    required this.previewColor,
    required this.onChanged,
    required this.onPickPressed,
  });

  final String label;
  final TextEditingController controller;
  final Color previewColor;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: previewColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: '#RRGGBB',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onPickPressed,
            icon: const Icon(Icons.colorize_outlined),
            label: Text(
              context.t('studio.theme_pick_color'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeColorPickerDialog extends StatefulWidget {
  const _ThemeColorPickerDialog({
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  @override
  State<_ThemeColorPickerDialog> createState() =>
      _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<_ThemeColorPickerDialog> {
  late HSVColor _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final color = _selectedColor.toColor();

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ColorSliderRow(
              label: context.t('ui.studio.hue'),
              value: _selectedColor.hue,
              max: 360,
              activeColor: color,
              onChanged: (value) {
                setState(() {
                  _selectedColor = _selectedColor.withHue(value);
                });
              },
            ),
            _ColorSliderRow(
              label: context.t('ui.studio.saturation'),
              value: _selectedColor.saturation,
              max: 1,
              activeColor: color,
              onChanged: (value) {
                setState(() {
                  _selectedColor = _selectedColor.withSaturation(value);
                });
              },
            ),
            _ColorSliderRow(
              label: context.t('ui.studio.brightness'),
              value: _selectedColor.value,
              max: 1,
              activeColor: color,
              onChanged: (value) {
                setState(() {
                  _selectedColor = _selectedColor.withValue(value);
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: Text(context.t('common.apply')),
        ),
      ],
    );
  }
}

class _ColorSliderRow extends StatelessWidget {
  const _ColorSliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  String get _formattedValue {
    if (max == 360) {
      return '${value.round()} deg';
    }
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            _formattedValue,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              thumbColor: activeColor,
            ),
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutEditor extends ConsumerWidget {
  const _AboutEditor({
    required this.repository,
  });

  final StudioRepository repository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchAppTitle = ref.watch(appConfigProvider).maybeWhen(
          data: (config) => config.textContent.get(
            'church_tab.app_title',
            fallback: '',
          ),
          orElse: () => '',
        );

    return FutureBuilder<Map<String, dynamic>>(
      future: repository.fetchAboutData(),
      builder: (context, initialSnapshot) {
        if (initialSnapshot.hasError) {
          return Center(
            child: Text(
              '${context.t('common.error_prefix')}: ${initialSnapshot.error}',
            ),
          );
        }
        if (!initialSnapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }

        return StreamBuilder<Map<String, dynamic>?>(
          stream: repository.watchAbout(),
          initialData: initialSnapshot.data!,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${context.t('common.error_prefix')}: ${snapshot.error}',
                ),
              );
            }

            final about = snapshot.data ?? initialSnapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: carouselBoxDecoration(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('studio.about_hint'),
                        ),
                        const SizedBox(height: 16),
                        _DetailLine(
                          label: context.t('studio.about_church_name'),
                          value: churchAppTitle,
                        ),
                        _DetailLine(
                          label: context.t('common.title'),
                          value: (about['title'] ?? '') as String,
                        ),
                        _DetailLine(
                          label: context.t('studio.about_tagline'),
                          value: (about['tagline'] ?? '') as String,
                        ),
                        _DetailLine(
                          label: context.t('common.description'),
                          value: (about['description'] ?? '') as String,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _showAboutEditor(
                            context,
                            repository,
                            initialData: about,
                            initialChurchAppTitle: churchAppTitle,
                          ),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(
                            context.t('studio.about_edit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BibleSwipeVersesEditor extends StatelessWidget {
  const _BibleSwipeVersesEditor({
    required this.repository,
  });

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: repository.watchBibleSwipeVerses(),
      initialData: const <String>[],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${context.t('common.error_prefix')}: ${snapshot.error}',
            ),
          );
        }

        final verses = snapshot.data ?? const <String>[];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: carouselBoxDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('studio.bible_swipe_hint'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => showBibleVersePickerSheet(
                        context,
                        title: context.t('studio.bible_swipe_add'),
                        initialBook: 'John',
                        initialChapter: 3,
                        initialVerse: 16,
                        onSave: ({
                          required book,
                          required chapter,
                          required verse,
                        }) {
                          final updated = [...verses, '$book $chapter:$verse'];
                          return repository.updateBibleSwipeVerses(updated);
                        },
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.t('studio.bible_swipe_add'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (verses.isEmpty)
                      Text(
                        context.t('studio.bible_swipe_empty'),
                      )
                    else
                      ...verses.asMap().entries.map(
                        (entry) {
                          final index = entry.key;
                          final verse = entry.value;
                          final parsed = BibleSwipeVerseModel.tryParse(verse);
                          return Container(
                            decoration: carouselBoxDecoration(context),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(verse),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: parsed == null
                                        ? null
                                        : () => showBibleVersePickerSheet(
                                              context,
                                              title: context.t(
                                                  'studio.bible_swipe_edit_single'),
                                              initialBook: parsed.book,
                                              initialChapter: parsed.chapter,
                                              initialVerse: parsed.verse,
                                              onSave: ({
                                                required book,
                                                required chapter,
                                                required verse,
                                              }) {
                                                final updated = [...verses];
                                                updated[index] =
                                                    '$book $chapter:$verse';
                                                return repository
                                                    .updateBibleSwipeVerses(
                                                        updated);
                                              },
                                            ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final updated = [...verses]
                                        ..removeAt(index);
                                      await repository.updateBibleSwipeVerses(
                                        updated,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.t(
                                                'studio.bible_swipe_updated'),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FooterEditor extends StatelessWidget {
  const _FooterEditor({
    required this.repository,
  });

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FooterCollectionCard(
          title: context.t('studio.footer_contacts_title'),
          initialFetch: repository.fetchContactItems,
          stream: repository.watchContactItems(),
          addLabel: context.t('studio.footer_contacts_add'),
          emptyText: context.t('studio.footer_contacts_empty'),
          tileTitle: (data) => (data['label'] ?? '') as String,
          tileSubtitle: (data) {
            final parts = <String>[
              if ((data['type'] ?? '').toString().isNotEmpty)
                '${context.t('studio.footer_type_prefix')}: ${data['type']}',
              if ((data['action'] ?? '').toString().isNotEmpty)
                '${context.t('studio.footer_action_prefix')}: ${data['action']}',
              '${context.t('studio.footer_order_prefix')}: ${data['order'] ?? 0}',
              '${context.t('studio.footer_active_prefix')}: ${data['isActive'] == true ? context.t('common.yes') : context.t('common.no')}',
            ];
            return parts.join('\n');
          },
          onAdd: () => _showFooterContactEditor(context, repository),
          onEdit: (doc) => _showFooterContactEditor(
            context,
            repository,
            doc: doc,
          ),
          onDelete: (doc) => repository.deleteContactItem(doc.id),
        ),
        const SizedBox(height: 16),
        _FooterCollectionCard(
          title: context.t('studio.footer_social_title'),
          initialFetch: repository.fetchSocialItems,
          stream: repository.watchSocialItems(),
          addLabel: context.t('studio.footer_social_add'),
          emptyText: context.t('studio.footer_social_empty'),
          tileTitle: (data) => (data['icon'] ?? '') as String,
          tileSubtitle: (data) {
            final parts = <String>[
              if ((data['platform'] ?? '').toString().isNotEmpty)
                '${context.t('studio.footer_platform_prefix')}: ${data['platform']}',
              if ((data['url'] ?? '').toString().isNotEmpty)
                '${context.t('studio.footer_url_prefix')}: ${data['url']}',
              '${context.t('studio.footer_order_prefix')}: ${data['order'] ?? 0}',
              '${context.t('studio.footer_active_prefix')}: ${data['isActive'] == true ? context.t('common.yes') : context.t('common.no')}',
            ];
            return parts.join('\n');
          },
          onAdd: () => _showFooterSocialEditor(context, repository),
          onEdit: (doc) => _showFooterSocialEditor(
            context,
            repository,
            doc: doc,
          ),
          onDelete: (doc) => repository.deleteSocialItem(doc.id),
        ),
      ],
    );
  }
}

class _FooterCollectionCard extends StatelessWidget {
  const _FooterCollectionCard({
    required this.title,
    required this.initialFetch,
    required this.stream,
    required this.addLabel,
    required this.emptyText,
    required this.tileTitle,
    required this.tileSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> Function()
      initialFetch;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final String addLabel;
  final String emptyText;
  final String Function(Map<String, dynamic>) tileTitle;
  final String Function(Map<String, dynamic>) tileSubtitle;
  final Future<void> Function() onAdd;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onEdit;
  final Future<void> Function(QueryDocumentSnapshot<Map<String, dynamic>> doc)
      onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: initialFetch(),
        builder: (context, initialSnapshot) {
          if (initialSnapshot.hasError) {
            return Text(
              '${context.t('common.error_prefix')}: ${initialSnapshot.error}',
            );
          }
          if (!initialSnapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }

          return StreamBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: stream,
            initialData: initialSnapshot.data!,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  '${context.t('common.error_prefix')}: ${snapshot.error}',
                );
              }

              final docs = snapshot.data ?? initialSnapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: Text(addLabel),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Text(emptyText)
                  else
                    ...docs.map(
                      (doc) => Container(
                        decoration: carouselBoxDecoration(context),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(tileTitle(doc.data())),
                          subtitle: Text(tileSubtitle(doc.data())),
                          isThreeLine: tileSubtitle(doc.data()).contains('\n'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => onEdit(doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await onDelete(doc);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _NotificationComposer extends StatefulWidget {
  const _NotificationComposer({
    required this.churchId,
    required this.onSend,
  });

  final String churchId;
  final Future<void> Function({
    required String title,
    required String body,
    required String topic,
  }) onSend;

  @override
  State<_NotificationComposer> createState() => _NotificationComposerState();
}

class _NotificationComposerState extends State<_NotificationComposer> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = 'church_${widget.churchId}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: carouselBoxDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${context.t('studio.notification_topic_prefix')}: $topic'),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.notification_title_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.t('studio.notification_body_label'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSending
                        ? null
                        : () async {
                            setState(() => _isSending = true);
                            try {
                              await widget.onSend(
                                title: _titleController.text.trim(),
                                body: _bodyController.text.trim(),
                                topic: topic,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.notification_queued'),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSending = false);
                              }
                            }
                          },
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t('studio.notification_send'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionsEditor extends StatelessWidget {
  const _SectionsEditor({
    required this.repository,
  });

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionGroupCard<HomeSectionConfigModel>(
          title: context.t('studio.section_home'),
          definitions: _homeSectionDefinitions,
          stream: repository.watchHomeSectionConfigs(),
          itemId: (item) => item.id,
          itemEnabled: (item) => item.enabled,
          itemOrder: (item) => item.order,
          onSave: ({required id, required enabled, required order}) {
            return repository.updateHomeSectionConfig(
              id: id,
              enabled: enabled,
              order: order,
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionGroupCard<ForYouSectionConfigModel>(
          title: context.t('studio.section_for_you'),
          definitions: _forYouSectionDefinitions,
          stream: repository.watchForYouSectionConfigs(),
          itemId: (item) => item.id,
          itemEnabled: (item) => item.enabled,
          itemOrder: (item) => item.order,
          onSave: ({required id, required enabled, required order}) {
            return repository.updateForYouSectionConfig(
              id: id,
              enabled: enabled,
              order: order,
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionGroupCard<ForYouSectionConfigModel>(
          title: context.t('studio.section_faith_engagement_items'),
          definitions: _faithEngagementItemDefinitions,
          stream: repository.watchForYouSectionConfigs(),
          itemId: (item) => item.id,
          itemEnabled: (item) => item.enabled,
          itemOrder: (item) => item.order,
          onSave: ({required id, required enabled, required order}) {
            return repository.updateForYouSectionConfig(
              id: id,
              enabled: enabled,
              order: order,
            );
          },
        ),
      ],
    );
  }
}

class _SectionGroupCard<T> extends StatelessWidget {
  const _SectionGroupCard({
    required this.title,
    required this.definitions,
    required this.stream,
    required this.itemId,
    required this.itemEnabled,
    required this.itemOrder,
    required this.onSave,
  });

  final String title;
  final List<_StudioSectionDefinition> definitions;
  final Stream<List<T>> stream;
  final String Function(T item) itemId;
  final bool Function(T item) itemEnabled;
  final int Function(T item) itemOrder;
  final Future<void> Function({
    required String id,
    required bool enabled,
    required int order,
  }) onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: carouselBoxDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<T>>(
          stream: stream,
          initialData: const [],
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                '${context.t('common.error_prefix')}: ${snapshot.error}',
              );
            }

            final items = snapshot.data ?? List<T>.empty(growable: false);
            final configById = {
              for (final item in items) itemId(item): item,
            };

            int resolvedOrder(_StudioSectionDefinition definition) {
              final config = configById[definition.id];
              return config == null
                  ? definition.defaultOrder
                  : itemOrder(config);
            }

            final orderedDefinitions = [...definitions]..sort((a, b) {
                return resolvedOrder(a).compareTo(resolvedOrder(b));
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orderedDefinitions.length,
                  onReorder: (oldIndex, newIndex) async {
                    await _runWithBlockingLoader(context, () async {
                      final reordered = [...orderedDefinitions];
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);

                      for (var i = 0; i < reordered.length; i++) {
                        final item = reordered[i];
                        final existing = configById[item.id];
                        await onSave(
                          id: item.id,
                          enabled:
                              existing != null ? itemEnabled(existing) : true,
                          order: (i + 1) * 10,
                        );
                      }
                    });

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.t('studio.section_updated'),
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final definition = orderedDefinitions[index];
                    final config = configById[definition.id];
                    final enabled = config != null ? itemEnabled(config) : true;

                    return _SectionConfigTile(
                      key: ValueKey(definition.id),
                      definition: definition,
                      enabled: enabled,
                      onToggle: (value) {
                        return onSave(
                          id: definition.id,
                          enabled: value,
                          order: resolvedOrder(definition),
                        );
                      },
                      dragHandle: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionConfigTile extends StatelessWidget {
  const _SectionConfigTile({
    super.key,
    required this.definition,
    required this.enabled,
    required this.onToggle,
    required this.dragHandle,
  });

  final _StudioSectionDefinition definition;
  final bool enabled;
  final Future<void> Function(bool value) onToggle;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: carouselBoxDecoration(context),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(definition.titleKey),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled
                      ? context.t('studio.section_enabled')
                      : context.t('studio.section_disabled'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (value) async {
              await _runWithBlockingLoader(
                context,
                () => onToggle(value),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.t('studio.section_updated'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          dragHandle,
        ],
      ),
    );
  }
}

class _StudioSectionDefinition {
  const _StudioSectionDefinition({
    required this.id,
    required this.titleKey,
    required this.defaultOrder,
  });

  final String id;
  final String titleKey;
  final int defaultOrder;
}

const List<_StudioSectionDefinition> _homeSectionDefinitions = [
  _StudioSectionDefinition(
    id: 'announcements',
    titleKey: 'studio.section_announcements',
    defaultOrder: 10,
  ),
  _StudioSectionDefinition(
    id: 'events',
    titleKey: 'studio.section_events',
    defaultOrder: 20,
  ),
  _StudioSectionDefinition(
    id: 'promise',
    titleKey: 'studio.section_promise',
    defaultOrder: 30,
  ),
  _StudioSectionDefinition(
    id: 'footer',
    titleKey: 'studio.section_footer',
    defaultOrder: 100,
  ),
];

const List<_StudioSectionDefinition> _forYouSectionDefinitions = [
  _StudioSectionDefinition(
    id: 'liveChurch',
    titleKey: 'studio.section_live_church',
    defaultOrder: 5,
  ),
  _StudioSectionDefinition(
    id: 'dailyVerse',
    titleKey: 'studio.section_daily_verse',
    defaultOrder: 10,
  ),
  _StudioSectionDefinition(
    id: 'faithEngagement',
    titleKey: 'studio.section_faith_engagement',
    defaultOrder: 12,
  ),
  _StudioSectionDefinition(
    id: 'prayForOthers',
    titleKey: 'studio.section_pray_for_others',
    defaultOrder: 15,
  ),
  _StudioSectionDefinition(
    id: 'featured',
    titleKey: 'studio.section_featured',
    defaultOrder: 20,
  ),
  _StudioSectionDefinition(
    id: 'article',
    titleKey: 'studio.section_article',
    defaultOrder: 30,
  ),
  _StudioSectionDefinition(
    id: 'footer',
    titleKey: 'studio.section_footer',
    defaultOrder: 100,
  ),
];

const List<_StudioSectionDefinition> _faithEngagementItemDefinitions = [
  _StudioSectionDefinition(
    id: 'dailyFaithLoop',
    titleKey: 'studio.section_daily_faith_loop',
    defaultOrder: 10,
  ),
  _StudioSectionDefinition(
    id: 'quizChallenge',
    titleKey: 'studio.section_quiz_challenge',
    defaultOrder: 20,
  ),
  _StudioSectionDefinition(
    id: 'circles',
    titleKey: 'studio.section_circles',
    defaultOrder: 30,
  ),
];

class _LiveChurchEditor extends StatefulWidget {
  const _LiveChurchEditor({required this.repository});

  final StudioRepository repository;

  @override
  State<_LiveChurchEditor> createState() => _LiveChurchEditorState();
}

class _LiveChurchEditorState extends State<_LiveChurchEditor> {
  final _formKey = GlobalKey<FormState>();
  final _channelController = TextEditingController();
  bool _enabled = true;
  bool _notifyWhenLive = false;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.repository.watchLiveChurchConfig(),
      builder: (context, snapshot) {
        if (!_initialized &&
            snapshot.connectionState != ConnectionState.waiting) {
          final data = snapshot.data;
          _channelController.text =
              (data?['youtubeChannelId'] ?? '').toString();
          _enabled = data?['enabled'] != false;
          _notifyWhenLive = data?['notifyWhenLive'] == true;
          _initialized = true;
        }

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.t('ui.studio.automatic_youtube_live_detection'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t(
                  'ui.studio.enter_the_permanent_channel_id_that_starts_with_uc',
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _channelController,
                decoration: InputDecoration(
                  labelText: context.t('ui.studio.youtube_channel_id'),
                  hintText: 'UCxxxxxxxxxxxxxxxxxxxxxx',
                  prefixIcon: const Icon(Icons.video_library_outlined),
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final channelId = value?.trim() ?? '';
                  if (channelId.isEmpty) {
                    return context.t('studio.youtube_channel_required');
                  }
                  if (!RegExp(r'^UC[A-Za-z0-9_-]{20,}$').hasMatch(channelId)) {
                    return context.t('studio.youtube_channel_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('ui.studio.automatic_detection')),
                subtitle: Text(
                  context.t(
                      'ui.studio.allow_the_backend_to_show_live_services_for_this_church'),
                ),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('ui.studio.notify_members_when_live')),
                subtitle: Text(
                  context.t(
                      'ui.studio.send_one_push_notification_when_a_new_service_goes_live'),
                ),
                value: _notifyWhenLive,
                onChanged: _enabled
                    ? (value) => setState(() => _notifyWhenLive = value)
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(context.t('ui.studio.save_live_church_settings')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repository.updateLiveChurchConfig(
        youtubeChannelId: _channelController.text,
        enabled: _enabled,
        notifyWhenLive: _notifyWhenLive,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.t('ui.studio.live_church_settings_saved'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AdminsEditor extends ConsumerWidget {
  const _AdminsEditor({
    required this.onSave,
  });

  final Future<void> Function(List<String> admins) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text('${context.t('common.error_prefix')}: $error'),
      ),
      data: (config) => _AdminsEditorForm(
        initialAdmins: config.admins,
        onSave: onSave,
      ),
    );
  }
}

class _AdminsEditorForm extends StatefulWidget {
  const _AdminsEditorForm({
    required this.initialAdmins,
    required this.onSave,
  });

  final List<String> initialAdmins;
  final Future<void> Function(List<String> admins) onSave;

  @override
  State<_AdminsEditorForm> createState() => _AdminsEditorFormState();
}

class _AdminsEditorFormState extends State<_AdminsEditorForm> {
  @override
  Widget build(BuildContext context) {
    return AdminEmailManager(
      initialAdmins: widget.initialAdmins,
      onSave: widget.onSave,
    );
  }
}

class _PromptSheetEditor extends ConsumerWidget {
  const _PromptSheetEditor({
    required this.onSave,
  });

  final Future<void> Function({
    required String title,
    required String desc,
    required bool enabled,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text('${context.t('common.error_prefix')}: $error'),
      ),
      data: (config) => _PromptSheetEditorForm(
        promptSheet: config.promptSheet,
        onSave: onSave,
      ),
    );
  }
}

class _AdminModeEditor extends ConsumerWidget {
  const _AdminModeEditor({
    required this.onSave,
  });

  final Future<void> Function({
    required bool enabled,
  }) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (error, _) => Center(
        child: Text(
          '${context.t('common.error_prefix')}: $error',
        ),
      ),
      data: (config) => _AdminModeEditorForm(
        initialEnabled: config.adminMode.enabled,
        onSave: onSave,
      ),
    );
  }
}

class _AdminModeEditorForm extends StatefulWidget {
  const _AdminModeEditorForm({
    required this.initialEnabled,
    required this.onSave,
  });

  final bool initialEnabled;
  final Future<void> Function({
    required bool enabled,
  }) onSave;

  @override
  State<_AdminModeEditorForm> createState() => _AdminModeEditorFormState();
}

class _AdminModeEditorFormState extends State<_AdminModeEditorForm> {
  late bool _enabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: carouselBoxDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.admin_mode_description'),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _enabled,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.t('studio.admin_mode_toggle'),
                  ),
                  subtitle: Text(
                    context.t('studio.admin_mode_hint'),
                  ),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _enabled = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              await widget.onSave(enabled: _enabled);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.admin_mode_updated'),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t('studio.admin_mode_save'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptSheetEditorForm extends StatefulWidget {
  const _PromptSheetEditorForm({
    required this.promptSheet,
    required this.onSave,
  });

  final PromptSheetModel promptSheet;
  final Future<void> Function({
    required String title,
    required String desc,
    required bool enabled,
  }) onSave;

  @override
  State<_PromptSheetEditorForm> createState() => _PromptSheetEditorFormState();
}

class _PromptSheetEditorFormState extends State<_PromptSheetEditorForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late bool _enabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.promptSheet.title);
    _descController = TextEditingController(text: widget.promptSheet.desc);
    _enabled = widget.promptSheet.enabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: carouselBoxDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('studio.prompt_description'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.t('common.title'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: context.t('common.description'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('common.enabled')),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            try {
                              await widget.onSave(
                                title: _titleController.text.trim(),
                                desc: _descController.text.trim(),
                                enabled: _enabled,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t('studio.prompt_updated'),
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t('studio.prompt_save'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showAboutEditor(
  BuildContext context,
  StudioRepository repository, {
  required Map<String, dynamic> initialData,
  required String initialChurchAppTitle,
}) {
  final churchAppTitleController =
      TextEditingController(text: initialChurchAppTitle);
  final titleController =
      TextEditingController(text: (initialData['title'] ?? '') as String);
  final taglineController =
      TextEditingController(text: (initialData['tagline'] ?? '') as String);
  final descriptionController = TextEditingController(
    text: (initialData['description'] ?? '') as String,
  );
  final missionController =
      TextEditingController(text: (initialData['mission'] ?? '') as String);
  final communityController =
      TextEditingController(text: (initialData['community'] ?? '') as String);
  final valuesController =
      TextEditingController(text: (initialData['values'] ?? '') as String);
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('studio.about_edit'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: churchAppTitleController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.about_church_name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: taglineController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.about_tagline'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.t('common.description'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: missionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.t('studio.about_mission'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: communityController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.t('studio.about_community'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: valuesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.t('studio.about_values'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setState(() => isSaving = true);
                              try {
                                await repository.updateAbout(
                                  churchAppTitle:
                                      churchAppTitleController.text.trim(),
                                  title: titleController.text.trim(),
                                  tagline: taglineController.text.trim(),
                                  description:
                                      descriptionController.text.trim(),
                                  mission: missionController.text.trim(),
                                  community: communityController.text.trim(),
                                  values: valuesController.text.trim(),
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t('studio.about_updated'),
                                    ),
                                  ),
                                );
                              } finally {
                                if (context.mounted) {
                                  setState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.t('common.save')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showPastorEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final contactController =
      TextEditingController(text: (data['contact'] ?? '') as String);
  final existingImageUrl = (data['imageUrl'] ?? '') as String;
  var setAsMain = (data['primary'] ?? false) as bool;
  PickedImageData? selectedImage;
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    doc == null ? 'studio.pastor_create' : 'studio.pastor_edit',
                    fallback: doc == null ? 'Add Pastor' : 'Edit Pastor',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: context.t('common.title'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: contactController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.event_contact'),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (picked == null) return;
                          final imageData =
                              await PickedImageData.fromXFile(picked);
                          if (imageData == null) return;
                          setState(() {
                            selectedImage = imageData;
                          });
                        },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    selectedImage == null
                        ? (existingImageUrl.isEmpty
                            ? context.t('super_admin.pastor_photo_pick')
                            : context.t('super_admin.pastor_photo_replace'))
                        : context.t('studio.announcement_change_image'),
                  ),
                ),
                if (selectedImage != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      color: Colors.black12,
                      child: Image.memory(
                        selectedImage!.bytes,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ] else if (existingImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 220),
                      color: Colors.black12,
                      child: Image.network(
                        existingImageUrl,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: setAsMain,
                  title: Text(
                    context.t('ui.studio.set_as_main'),
                  ),
                  subtitle: Text(
                    context.t(
                        'ui.studio.show_this_pastor_as_the_main_pastor_in_the_app'),
                  ),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            setAsMain = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final contact = contactController.text.trim();
                            if (title.isEmpty || contact.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                        'ui.studio.please_add_pastor_photo_title_and_contact_b1fe'),
                                  ),
                                ),
                              );
                              return;
                            }
                            if (doc == null &&
                                selectedImage == null &&
                                existingImageUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.t(
                                        'ui.studio.please_add_pastor_photo_title_and_contact_b1fe'),
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => isSaving = true);
                            try {
                              final payload = {
                                'title': title,
                                'contact': contact,
                              };
                              if (doc == null) {
                                final createdId = await repository.createPastor(
                                  data: payload,
                                  imageFile: selectedImage!,
                                );
                                if (setAsMain) {
                                  await repository.setPrimaryPastor(createdId);
                                }
                              } else {
                                await repository.updatePastor(
                                  id: doc.id,
                                  data: payload,
                                  imageFile: selectedImage,
                                  existingImageUrl: existingImageUrl,
                                );
                                if (setAsMain) {
                                  await repository.setPrimaryPastor(doc.id);
                                }
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _showFooterContactEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final labelController =
      TextEditingController(text: (data['label'] ?? '') as String);
  final actionController =
      TextEditingController(text: (data['action'] ?? '') as String);
  final orderController = TextEditingController(text: '${data['order'] ?? 1}');
  var type = (data['type'] ?? 'phone') as String;
  var isActive = (data['isActive'] ?? true) as bool;
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    doc == null
                        ? 'studio.footer_contact_create'
                        : 'studio.footer_contact_edit',
                    fallback:
                        doc == null ? 'Add Contact Item' : 'Edit Contact Item',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AppDropdownField<String>(
                  initialValue: type,
                  labelText: context.t('studio.footer_type_label'),
                  items: [
                    DropdownMenuItem(
                        value: 'phone',
                        child: Text(context.t('ui.studio.phone'))),
                    DropdownMenuItem(
                        value: 'email',
                        child: Text(context.t('ui.studio.email'))),
                    DropdownMenuItem(
                        value: 'location',
                        child: Text(context.t('ui.studio.location'))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => type = value);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_label_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: actionController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_action_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_order_label'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('common.active')),
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            final payload = {
                              'label': labelController.text.trim(),
                              'type': type,
                              'action': actionController.text.trim(),
                              'order':
                                  int.tryParse(orderController.text.trim()) ??
                                      1,
                              'isActive': isActive,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            try {
                              if (doc == null) {
                                await repository.createContactItem(payload);
                              } else {
                                await repository.updateContactItem(
                                    doc.id, payload);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _showFooterSocialEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final iconController =
      TextEditingController(text: (data['icon'] ?? '') as String);
  final platformController =
      TextEditingController(text: (data['platform'] ?? '') as String);
  final urlController =
      TextEditingController(text: (data['url'] ?? '') as String);
  final orderController = TextEditingController(text: '${data['order'] ?? 1}');
  var isActive = (data['isActive'] ?? true) as bool;
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(
                    doc == null
                        ? 'studio.footer_social_create'
                        : 'studio.footer_social_edit',
                    fallback:
                        doc == null ? 'Add Social Item' : 'Edit Social Item',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: iconController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_icon_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: platformController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_platform_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_url_label'),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: orderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.t('studio.footer_order_label'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('common.active')),
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            final payload = {
                              'icon': iconController.text.trim(),
                              'platform': platformController.text.trim(),
                              'url': urlController.text.trim(),
                              'order':
                                  int.tryParse(orderController.text.trim()) ??
                                      1,
                              'isActive': isActive,
                              'updatedAt': FieldValue.serverTimestamp(),
                            };
                            try {
                              if (doc == null) {
                                await repository.createSocialItem(payload);
                              } else {
                                await repository.updateSocialItem(
                                    doc.id, payload);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _showEventEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final descriptionController =
      TextEditingController(text: (data['description'] ?? '') as String);
  final contactController =
      TextEditingController(text: (data['contact'] ?? '') as String);
  final locationController =
      TextEditingController(text: (data['location'] ?? '') as String);
  final timingController =
      TextEditingController(text: (data['timing'] ?? '') as String);
  DateTime? startAt = (data['startAt'] as Timestamp?)?.toDate();
  final expiryController = TextEditingController(
    text: _formatOptionalDateTime((data['expiryAt'] as Timestamp?)?.toDate()),
  );
  String type = (data['type'] ?? 'family') as String;
  bool isActive = (data['isActive'] ?? true) as bool;
  bool repeatsWeekly = data['isRecurring'] == true &&
      (data['recurrenceFrequency'] ?? '') == 'weekly';
  DateTime? expiryAt = (data['expiryAt'] as Timestamp?)?.toDate();
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t(
                      doc == null ? 'studio.event_create' : 'studio.event_edit',
                      fallback: doc == null ? 'Create event' : 'Edit event',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: context.t('common.description'),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<String>(
                    initialValue: type,
                    labelText: context.t('studio.event_type'),
                    items: [
                      DropdownMenuItem(
                        value: 'family',
                        child: Text(context.t('studio.event_type_family')),
                      ),
                      DropdownMenuItem(
                        value: 'kids',
                        child: Text(context.t('studio.event_type_kids')),
                      ),
                      DropdownMenuItem(
                        value: 'youth',
                        child: Text(context.t('studio.event_type_youth')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: contactController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.event_contact'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: context.t('studio.event_location'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: timingController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: context.t('studio.event_timing'),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (timingController.text.trim().isNotEmpty)
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        timingController.clear();
                                        startAt = null;
                                      });
                                    },
                              icon: const Icon(Icons.clear),
                            ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: startAt ?? now,
                                      firstDate: DateTime(now.year - 1),
                                      lastDate: DateTime(now.year + 10),
                                    );
                                    if (pickedDate == null ||
                                        !context.mounted) {
                                      return;
                                    }

                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        startAt ?? now,
                                      ),
                                    );

                                    final resolved = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime?.hour ?? 9,
                                      pickedTime?.minute ?? 0,
                                    );
                                    final formatted =
                                        _formatOptionalDateTime(resolved);

                                    if (!context.mounted) return;
                                    setState(() {
                                      startAt = resolved;
                                      timingController.text = formatted;
                                    });
                                  },
                            icon: const Icon(Icons.event_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.t('common.active')),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                  if (doc == null) ...[
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('ui.studio.repeat_weekly')),
                      subtitle: Text(
                        context.t(
                            'ui.studio.cloud_functions_will_move_this_event_to_the_next_week_a'),
                      ),
                      value: repeatsWeekly,
                      onChanged: (value) {
                        setState(() {
                          repeatsWeekly = value;
                          if (value) {
                            expiryAt = null;
                            expiryController.clear();
                          }
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (!repeatsWeekly)
                    AppTextField(
                      controller: expiryController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: context.t('studio.expiry_at_label'),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (expiryController.text.trim().isNotEmpty)
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setState(() {
                                          expiryAt = null;
                                          expiryController.clear();
                                        });
                                      },
                                icon: const Icon(Icons.clear),
                              ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: expiryAt ?? now,
                                        firstDate: DateTime(now.year - 1),
                                        lastDate: DateTime(now.year + 10),
                                      );
                                      if (pickedDate == null ||
                                          !context.mounted) {
                                        return;
                                      }

                                      final pickedTime = await showTimePicker(
                                        context: context,
                                        initialTime: expiryAt == null
                                            ? TimeOfDay.fromDateTime(now)
                                            : TimeOfDay.fromDateTime(expiryAt!),
                                      );

                                      if (!context.mounted) return;
                                      final resolved = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime?.hour ?? 23,
                                        pickedTime?.minute ?? 59,
                                      );

                                      setState(() {
                                        expiryAt = resolved;
                                        expiryController.text =
                                            _formatOptionalDateTime(resolved);
                                      });
                                    },
                              icon: const Icon(Icons.event_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                              if (repeatsWeekly && startAt == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.t(
                                          'ui.studio.choose_the_first_event_timing_before_enabling_weekly_re'),
                                    ),
                                  ),
                                );
                                return;
                              }

                              final recurringExpiryAt =
                                  repeatsWeekly && startAt != null
                                      ? DateTime(
                                          startAt!.year,
                                          startAt!.month,
                                          startAt!.day,
                                          23,
                                          59,
                                          59,
                                          999,
                                        )
                                      : expiryAt;
                              final payload = {
                                'title': titleController.text.trim(),
                                'description':
                                    descriptionController.text.trim(),
                                'type': type,
                                'contact': contactController.text.trim(),
                                'location': locationController.text.trim(),
                                'timing': timingController.text.trim(),
                                'startAt': startAt == null
                                    ? null
                                    : Timestamp.fromDate(startAt!),
                                'isActive': isActive,
                                'expiryAt': recurringExpiryAt == null
                                    ? null
                                    : Timestamp.fromDate(recurringExpiryAt),
                              };
                              if (doc == null && repeatsWeekly) {
                                await repository.createWeeklyRecurringEvent(
                                  eventData: payload,
                                  startAt: startAt!,
                                );
                              } else if (doc == null) {
                                await repository.createEvent(payload);
                              } else {
                                await repository.updateEvent(doc.id, payload);
                              }
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              doc == null ? 'common.create' : 'common.save',
                              fallback: doc == null ? 'Create' : 'Save',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showAnnouncementEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final bodyController =
      TextEditingController(text: (data['body'] ?? '') as String);
  final priorityController =
      TextEditingController(text: '${(data['priority'] ?? 0) as int}');
  final existingImageUrl = (data['imageUrl'] ?? '') as String;
  final expiryController = TextEditingController(
    text: _formatOptionalDateTime((data['expiryAt'] as Timestamp?)?.toDate()),
  );
  final formKey = GlobalKey<FormState>();
  PickedImageData? selectedImage;
  bool isActive = (data['isActive'] ?? true) as bool;
  DateTime? expiryAt = (data['expiryAt'] as Timestamp?)?.toDate();
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    heightFactor: 0.94,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(
                        doc == null
                            ? 'studio.announcement_create'
                            : 'studio.announcement_edit',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: context.t('settings.cancel'),
                    onPressed:
                        isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: titleController,
                          label: context.t('common.title'),
                          textInputAction: TextInputAction.next,
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? context.t('faith.field_required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: bodyController,
                          label: context.t('studio.announcement_body'),
                          keyboardType: TextInputType.multiline,
                          minLines: 3,
                          maxLines: 5,
                          validator: (value) => value?.trim().isEmpty ?? true
                              ? context.t('faith.field_required')
                              : null,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final picked =
                                        await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      imageQuality: 85,
                                    );
                                    if (picked == null || !context.mounted) {
                                      return;
                                    }
                                    final imageData =
                                        await PickedImageData.fromXFile(picked);
                                    if (imageData == null || !context.mounted) {
                                      return;
                                    }
                                    setState(() => selectedImage = imageData);
                                  },
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(
                              selectedImage == null
                                  ? (existingImageUrl.isEmpty
                                      ? context
                                          .t('studio.announcement_upload_image')
                                      : context.t(
                                          'studio.announcement_replace_image'))
                                  : context
                                      .t('studio.announcement_change_image'),
                            ),
                          ),
                        ),
                        if (selectedImage != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.memory(
                                selectedImage!.bytes,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ] else if (existingImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                existingImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: priorityController,
                          label: context.t('studio.priority_label'),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 14),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 4,
                            ),
                            title: Text(context.t('common.active')),
                            secondary: const Icon(Icons.visibility_outlined),
                            value: isActive,
                            onChanged: isSaving
                                ? null
                                : (value) => setState(() => isActive = value),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: expiryController,
                          readOnly: true,
                          label: context.t('studio.expiry_at_label'),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (expiryController.text.trim().isNotEmpty)
                                IconButton(
                                  tooltip: context.t('common.clear'),
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            expiryAt = null;
                                            expiryController.clear();
                                          });
                                        },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final now = DateTime.now();
                                        final pickedDate = await showDatePicker(
                                          context: context,
                                          initialDate: expiryAt ?? now,
                                          firstDate: DateTime(now.year - 1),
                                          lastDate: DateTime(now.year + 10),
                                        );
                                        if (pickedDate == null ||
                                            !context.mounted) {
                                          return;
                                        }

                                        final pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: expiryAt == null
                                              ? TimeOfDay.fromDateTime(now)
                                              : TimeOfDay.fromDateTime(
                                                  expiryAt!),
                                        );
                                        if (!context.mounted) return;

                                        final resolved = DateTime(
                                          pickedDate.year,
                                          pickedDate.month,
                                          pickedDate.day,
                                          pickedTime?.hour ?? 23,
                                          pickedTime?.minute ?? 59,
                                        );

                                        setState(() {
                                          expiryAt = resolved;
                                          expiryController.text =
                                              _formatOptionalDateTime(resolved);
                                        });
                                      },
                                icon: const Icon(Icons.event_outlined),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final failureMessage =
                              context.t('studio.announcement_save_failed');
                          setState(() => isSaving = true);
                          try {
                            final payload = {
                              'title': titleController.text.trim(),
                              'body': bodyController.text.trim(),
                              'priority': int.tryParse(
                                    priorityController.text.trim(),
                                  ) ??
                                  0,
                              'isActive': isActive,
                              'expiryAt': expiryAt == null
                                  ? null
                                  : Timestamp.fromDate(expiryAt!),
                            };
                            if (doc == null) {
                              await repository.createAnnouncement(
                                data: payload,
                                imageFile: selectedImage,
                              );
                            } else {
                              await repository.updateAnnouncement(
                                id: doc.id,
                                data: payload,
                                imageFile: selectedImage,
                                existingImageUrl: existingImageUrl,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failureMessage)),
                            );
                          } finally {
                            if (context.mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          context.t(
                            doc == null ? 'common.create' : 'common.save',
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      });
    },
  );
}

Future<void> _showArticleEditor(
  BuildContext context,
  StudioRepository repository, {
  QueryDocumentSnapshot<Map<String, dynamic>>? doc,
}) {
  final data = doc?.data() ?? <String, dynamic>{};
  final titleController =
      TextEditingController(text: (data['title'] ?? '') as String);
  final descriptionController =
      TextEditingController(text: (data['description'] ?? '') as String);
  final contentController =
      TextEditingController(text: (data['content'] ?? '') as String);
  var isSaving = false;

  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t(
                      doc == null
                          ? 'studio.article_create'
                          : 'studio.article_edit',
                      fallback: doc == null ? 'Create article' : 'Edit article',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: context.t('common.title'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: context.t('common.description'),
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      labelText: context.t('common.content'),
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setState(() => isSaving = true);
                            try {
                              final payload = {
                                'title': titleController.text.trim(),
                                'description':
                                    descriptionController.text.trim(),
                                'content': contentController.text.trim(),
                              };
                              if (doc == null) {
                                await repository.createArticle(payload);
                              } else {
                                await repository.updateArticle(doc.id, payload);
                              }
                              if (context.mounted) Navigator.pop(context);
                            } finally {
                              if (context.mounted) {
                                setState(() => isSaving = false);
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            context.t(
                              doc == null ? 'common.create' : 'common.save',
                              fallback: doc == null ? 'Create' : 'Save',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    titleController.dispose();
    descriptionController.dispose();
    contentController.dispose();
  });
}

Future<void> _runWithBlockingLoader(
  BuildContext context,
  Future<void> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: AppLoadingIndicator()),
  );

  try {
    await action();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

String _formatOptionalDateTime(DateTime? value) {
  if (value == null) return '';
  return DateFormat('d MMM yyyy, h:mm a').format(value);
}
