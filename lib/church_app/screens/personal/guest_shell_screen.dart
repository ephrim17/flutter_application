import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/learning_module_providers.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_library_screen.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shown whenever a signed-in user has no approved membership — covers all
/// four situations in §5.3, not just "pending". Personal features only:
/// Bible, (global) Learning, and church discovery/request-access. No new
/// security rules needed here — everything read is either the user's own
/// data or already public (§5.3); this is a UI-shell decision, not an
/// authorization one.
class GuestShellScreen extends ConsumerStatefulWidget {
  const GuestShellScreen({super.key});

  @override
  ConsumerState<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends ConsumerState<GuestShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.t('guest_shell.title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: ref.t('guest_shell.tab_bible')),
            Tab(text: ref.t('guest_shell.tab_learning')),
            Tab(text: ref.t('guest_shell.tab_my_churches')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BibleLibraryScreen(),
          _GuestLearningTab(),
          _MyChurchesTab(),
        ],
      ),
    );
  }
}

class _GuestLearningTab extends ConsumerWidget {
  const _GuestLearningTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(globalPublishedLearningModulesProvider);
    return modulesAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (_, __) => Center(child: Text(ref.t('guest_shell.learning_error'))),
      data: (modules) {
        if (modules.isEmpty) {
          return Center(child: Text(ref.t('guest_shell.learning_empty')));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return Card(
              child: ListTile(
                title: Text(module.title),
                subtitle: Text(
                  module.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MyChurchesTab extends ConsumerWidget {
  const _MyChurchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(myMembershipsProvider);
    final churchesAsync = ref.watch(churchesProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: membershipsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (memberships) {
              final pending =
                  memberships.where((m) => !m.approved).toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.t('guest_shell.pending_section_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final membership in pending)
                      _PendingMembershipTile(membership: membership),
                  ],
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              ref.t('guest_shell.browse_section_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        churchesAsync.when(
          loading: () =>
              const SliverToBoxAdapter(child: AppLoadingIndicator()),
          error: (_, __) => SliverToBoxAdapter(
            child: Center(child: Text(ref.t('guest_shell.churches_error'))),
          ),
          data: (churches) => SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.builder(
              itemCount: churches.length,
              itemBuilder: (context, index) {
                final church = churches[index];
                return Card(
                  child: ListTile(
                    leading: ChurchLogoAvatar(logo: church.logo, size: 40),
                    title: Text(church.name),
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoginRequestScreen(
                            churchId: church.id,
                            churchName: church.name,
                            churchLogo: church.logo,
                          ),
                        ),
                      ),
                      child: Text(ref.t('guest_shell.request_access_action')),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingMembershipTile extends ConsumerWidget {
  const _PendingMembershipTile({required this.membership});

  final ChurchMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchAsync = ref.watch(churchByIdProvider(membership.churchId));
    final Church? church = churchAsync.value;
    return Card(
      child: ListTile(
        leading: ChurchLogoAvatar(logo: church?.logo ?? '', size: 40),
        title: Text(church?.name ?? membership.churchId),
        subtitle: Text(ref.t('guest_shell.pending_status')),
      ),
    );
  }
}
