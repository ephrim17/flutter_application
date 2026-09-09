import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/request_church_access_screen.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_library_screen.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shown whenever a signed-in user has no approved membership — covers all
/// four situations in §5.3, not just "pending". Personal features only:
/// Bible and church discovery/request-access. No new security rules needed
/// here — everything read is either the user's own data or already public
/// (§5.3); this is a UI-shell decision, not an authorization one.
///
/// Learning was dropped from this shell on user feedback — Church Tree
/// modules stay reachable inside any church instead (§5.6).
class GuestShellScreen extends ConsumerStatefulWidget {
  const GuestShellScreen({super.key});

  @override
  ConsumerState<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends ConsumerState<GuestShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

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
            Tab(text: ref.t('guest_shell.tab_my_churches')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          BibleLibraryScreen(),
          _MyChurchesTab(),
        ],
      ),
    );
  }
}

class _MyChurchesTab extends ConsumerWidget {
  const _MyChurchesTab();

  Future<void> _enterChurch(
    BuildContext context,
    WidgetRef ref,
    Church church,
  ) async {
    await ChurchLocalStorage()
        .saveChurch(id: church.id, name: church.name, logo: church.logo);
    if (!context.mounted) return;
    ref.read(selectedChurchProvider.notifier).state = church;
    ref.read(forcePreflowThemeProvider.notifier).state = false;
    ref.invalidate(currentChurchIdProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid != null) {
      unawaited(
        UserIdentityRepository(firestore: ref.read(firestoreProvider))
            .setLastActiveChurchId(uid, church.id),
      );
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppEntry()),
      (route) => false,
    );
  }

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
              final approved =
                  memberships.where((m) => m.approved).toList();
              if (approved.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.t('guest_shell.your_churches_section_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final membership in approved)
                      _ApprovedMembershipTile(
                        membership: membership,
                        onEnter: (church) =>
                            _enterChurch(context, ref, church),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
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
          data: (churches) {
            final requestedChurchIds = membershipsAsync.asData?.value
                    .map((m) => m.churchId)
                    .toSet() ??
                const <String>{};
            final browsableChurches = churches
                .where((church) => !requestedChurchIds.contains(church.id))
                .toList();
            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.builder(
                itemCount: browsableChurches.length,
                itemBuilder: (context, index) {
                  final church = browsableChurches[index];
                  return Card(
                    child: ListTile(
                      leading: ChurchLogoAvatar(logo: church.logo, size: 40),
                      title: Text(church.name),
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RequestChurchAccessScreen(
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
            );
          },
        ),
      ],
    );
  }
}

class _ApprovedMembershipTile extends ConsumerWidget {
  const _ApprovedMembershipTile({
    required this.membership,
    required this.onEnter,
  });

  final ChurchMembership membership;
  final void Function(Church church) onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churchAsync = ref.watch(churchByIdProvider(membership.churchId));
    final Church? church = churchAsync.value;
    return Card(
      child: ListTile(
        leading: ChurchLogoAvatar(logo: church?.logo ?? '', size: 40),
        title: Text(church?.name ?? membership.churchId),
        subtitle: Text(ref.t('guest_shell.approved_status')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: church == null ? null : () => onEnter(church),
      ),
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
