import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/screens/super_admin/create_church_screen.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/services/super_admin/super_admin_church_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('super_admin.title', fallback: 'Super Admin'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: context.t(
              'super_admin.back_to_normal_flow',
              fallback: 'Back To Church Selection',
            ),
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
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Text(
                      '${context.t('common.error_prefix', fallback: 'Error')}: $error',
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
                      length: 2,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Column(
                              children: [
                                Container(
                                  decoration: carouselBoxDecoration(context),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.t(
                                          'super_admin.title',
                                          fallback: 'Super Admin',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        context.t(
                                          'super_admin.subtitle',
                                          fallback:
                                              'Manage platform-level churches before entering the church app.',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: SolidButton(
                                          label: context.t(
                                            'super_admin.create_church',
                                            fallback: 'Create Church',
                                          ),
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
                                            FirebaseAnalytics.instance.logEvent(
                                              name: 'church_created_super_admin',
                                              parameters: {
                                                'result': createResult,
                                              },
                                            );
                                            final snackText =
                                                switch (createResult) {
                                              'created_with_email' => context.t(
                                                  'super_admin.create_success',
                                                  fallback:
                                                      'Church created successfully. Password setup email sent to the admin.',
                                                ),
                                              'created_email_failed' =>
                                                context.t(
                                                  'super_admin.create_success_email_failed',
                                                  fallback:
                                                      'Church created successfully, but the password setup email could not be sent to the admin.',
                                                ),
                                              _ => context.t(
                                                  'super_admin.create_success_no_account',
                                                  fallback:
                                                      'Church created successfully without account setup.',
                                                ),
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
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  decoration: carouselBoxDecoration(context),
                                  padding: const EdgeInsets.all(16),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _query = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: context.t(
                                        'super_admin.search_hint',
                                        fallback: 'Search churches',
                                      ),
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
                                const SizedBox(height: 16),
                                Container(
                                  decoration: carouselBoxDecoration(context),
                                  padding: const EdgeInsets.all(6),
                                  child: TabBar(
                                    dividerColor: Colors.transparent,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    tabs: [
                                      Tab(
                                        text:
                                            'Not Approved (${pendingChurches.length})',
                                      ),
                                      Tab(
                                        text:
                                            'Approved (${approvedChurches.length})',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _ChurchListTab(
                                  churches: pendingChurches,
                                  emptyMessage: context.t(
                                    'super_admin.pending_section_empty',
                                    fallback:
                                        'No churches are waiting for approval right now.',
                                  ),
                                ),
                                _ChurchListTab(
                                  churches: approvedChurches,
                                  emptyMessage: context.t(
                                    'super_admin.approved_section_empty',
                                    fallback:
                                        'No approved churches match your search yet.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
    final isPublicRegistration = church.registrationSource == 'public';

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
                        context.t(
                          'super_admin.status_updated',
                          fallback: 'Church status updated',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AdminChip(
                label: isPublicRegistration
                    ? 'Created by Public'
                    : 'Created by Super Admin',
                backgroundColor: isPublicRegistration
                    ? Colors.blue.shade50
                    : Colors.purple.shade50,
                foregroundColor: isPublicRegistration
                    ? Colors.blue.shade800
                    : Colors.purple.shade800,
              ),
            ],
          ),
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
                      context.t(
                        'super_admin.edit_success',
                        fallback: 'Church updated successfully',
                      ),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                context.t(
                  'super_admin.edit_church',
                  fallback: 'Edit Church',
                ),
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

class _AdminChip extends StatelessWidget {
  const _AdminChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
