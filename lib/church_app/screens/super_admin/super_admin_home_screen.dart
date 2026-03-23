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

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        Container(
                          decoration: carouselBoxDecoration(context),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(
                                  'super_admin.title',
                                  fallback: 'Super Admin',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t(
                                  'super_admin.subtitle',
                                  fallback:
                                      'Manage platform-level churches before entering the church app.',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium,
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
                                    final passwordEmailSent =
                                        await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateChurchScreen(),
                                      ),
                                    );
                                    if (passwordEmailSent == null ||
                                        !context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.t(
                                            passwordEmailSent
                                                ? 'super_admin.create_success'
                                                : 'super_admin.create_success_email_failed',
                                            fallback: passwordEmailSent
                                                ? 'Church created successfully. Password setup email sent to the admin.'
                                                : 'Church created successfully, but the password setup email could not be sent to the admin.',
                                          ),
                                        ),
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
                        Text(
                          context.t(
                            'super_admin.directory_title',
                            fallback: 'All Churches',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (filteredChurches.isEmpty)
                          Container(
                            decoration: carouselBoxDecoration(context),
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              context.t(
                                'super_admin.directory_empty',
                                fallback: 'No churches found yet.',
                              ),
                            ),
                          )
                        else
                          ...filteredChurches.map(
                            (church) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _SuperAdminChurchTile(church: church),
                            ),
                          ),
                      ],
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
    return Container(
      decoration: carouselBoxDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ChurchLogoAvatar(
          logo: church.logo,
          size: 44,
        ),
        title: Text(church.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(church.id),
            if (church.pastorName.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(church.pastorName),
            ],
          ],
        ),
        trailing: Switch(
          value: church.enabled,
          onChanged: (value) async {
            await ref.read(churchRepositoryProvider).updateChurchEnabled(
                  churchId: church.id,
                  enabled: value,
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
      ),
    );
  }
}
