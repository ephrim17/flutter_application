import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_group_member_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/church_group_members_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChurchGroupsScreen extends ConsumerStatefulWidget {
  const ChurchGroupsScreen({super.key});

  @override
  ConsumerState<ChurchGroupsScreen> createState() => _ChurchGroupsScreenState();
}

class _ChurchGroupsScreenState extends ConsumerState<ChurchGroupsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: churchGroupDefinitions.length,
      vsync: this,
    )..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  void _recreateTabController(int length) {
    final previousIndex =
        _tabController.index.clamp(0, length > 0 ? length - 1 : 0);
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: previousIndex,
    )..addListener(_handleTabChanged);
  }

  Future<MembersRepository?> _membersRepository() async {
    final churchId = await ref.read(currentChurchIdProvider.future);
    if (churchId == null) return null;

    return MembersRepository(
      firestore: ref.read(firestoreProvider),
      churchId: churchId,
    );
  }

  Future<void> _addMemberToGroup(
    AppUser member,
    ChurchGroupDefinition group,
  ) async {
    final repo = await _membersRepository();
    if (repo == null) return;

    await repo.updateMemberChurchGroups(
      member.uid,
      churchGroupIds: [...member.churchGroupIds, group.id],
    );
  }

  Future<void> _removeMemberFromGroup(
    AppUser member,
    ChurchGroupDefinition group,
  ) async {
    final repo = await _membersRepository();
    if (repo == null) return;

    await repo.updateMemberChurchGroups(
      member.uid,
      churchGroupIds: member.churchGroupIds
          .where((groupId) => groupId != group.id)
          .toList(),
    );
  }

  Future<void> _showAddMembersSheet(
    BuildContext context,
    ChurchGroupDefinition group,
  ) async {
    final repo = await _membersRepository();
    if (repo == null) return;

    final members = await repo.getMembersOnce();
    final availableMembers = members
        .where((member) => !member.churchGroupIds.contains(group.id))
        .toList();

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SafeArea(
            child: availableMembers.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context
                              .t('groups.add_to_group', fallback: 'Add to {group}')
                              .replaceAll('{group}', group.label),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.t(
                            'groups.all_members_assigned',
                            fallback:
                                'All members are already assigned to this group.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: availableMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final member = availableMembers[index];
                      return Container(
                        decoration: carouselBoxDecoration(context),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.name.isNotEmpty
                                  ? member.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            [
                              if (member.phone.trim().isNotEmpty) member.phone,
                              if (member.email.trim().isNotEmpty) member.email,
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () async {
                            await _addMemberToGroup(member, group);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context
                                      .t(
                                        'groups.member_added',
                                        fallback: '{member} added to {group}',
                                      )
                                      .replaceAll('{member}', member.name)
                                      .replaceAll('{group}', group.label),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<void> _showMemberActionsSheet(
    BuildContext context,
    ChurchGroupMember member,
    ChurchGroupDefinition group,
  ) async {
    final shouldRemove = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(
                  context
                      .t(
                        'groups.remove_from_group',
                        fallback: 'Remove from {group}',
                      )
                      .replaceAll('{group}', group.label),
                ),
                subtitle: Text(
                  context.t(
                    'groups.remove_from_group_message',
                    fallback: 'This removes the member only from this group.',
                  ),
                ),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );

    if (shouldRemove != true) return;

    final repo = await _membersRepository();
    if (repo == null) return;
    final fullMember = await repo.getMemberById(member.uid);
    if (fullMember == null) return;

    await _removeMemberFromGroup(fullMember, group);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context
              .t(
                'groups.member_removed',
                fallback: '{member} removed from {group}',
              )
              .replaceAll('{member}', member.name)
              .replaceAll('{group}', group.label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final currentUser = ref.watch(appUserProvider).value;
    final visibleGroups = isAdmin
        ? churchGroupDefinitions
        : churchGroupDefinitions
            .where(
              (group) => currentUser?.churchGroupIds.contains(group.id) ?? false,
            )
            .toList();

    if (visibleGroups.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(
            text: context.t('groups.title', fallback: 'Church Groups'),
          ),
        ),
        body: Center(
          child: Text(
            context.t(
              'groups.empty_state',
              fallback: 'No church groups are assigned yet.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    if (_tabController.length != visibleGroups.length) {
      _recreateTabController(visibleGroups.length);
    }

    final currentGroup = visibleGroups[_tabController.index];

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('groups.title', fallback: 'Church Groups'),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: context
                  .t('groups.add_to_group', fallback: 'Add to {group}')
                  .replaceAll('{group}', currentGroup.label),
              onPressed: () => _showAddMembersSheet(context, currentGroup),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              tabs: [
                for (final group in visibleGroups)
                  Tab(text: group.label),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: _CurrentGroupSummary(group: currentGroup),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final group in visibleGroups)
                  _GroupMembersTab(
                    group: group,
                    onMemberTap: isAdmin
                        ? (member) =>
                            _showMemberActionsSheet(context, member, group)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentGroupSummary extends ConsumerWidget {
  const _CurrentGroupSummary({
    required this.group,
  });

  final ChurchGroupDefinition group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(churchGroupMembersProvider(group.id));

    return Container(
      width: double.infinity,
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: membersAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context.t(
                'groups.group_load_failed',
                fallback: 'Unable to load this group right now.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        data: (members) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context
                  .t(
                    'groups.group_member_count',
                    fallback: '{count} members in this group',
                  )
                  .replaceAll('{count}', members.length.toString()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMembersTab extends ConsumerWidget {
  const _GroupMembersTab({
    required this.group,
    this.onMemberTap,
  });

  final ChurchGroupDefinition group;
  final ValueChanged<ChurchGroupMember>? onMemberTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(churchGroupMembersProvider(group.id));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(
          context
              .t('groups.tab_load_failed', fallback: 'Unable to load {group}.')
              .replaceAll('{group}', group.label),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              Container(
                decoration: carouselBoxDecoration(context),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(
                        'groups.empty_group_members',
                        fallback: 'No members are assigned to this group yet.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final member = members[index];
            return Container(
              decoration: carouselBoxDecoration(context),
              child: ListTile(
                onTap: onMemberTap == null ? null : () => onMemberTap!(member),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  ),
                ),
                title: Text(member.name),
                subtitle: Text(
                  [
                    if (member.category.trim().isNotEmpty)
                      _formatCategory(context, member.category),
                    if (member.phone.trim().isNotEmpty) member.phone,
                  ].join(' • '),
                ),
                trailing: member.email.trim().isEmpty
                    ? (onMemberTap == null ? null : const Icon(Icons.more_horiz))
                    : SizedBox(
                        width: 120,
                        child: Text(
                          member.email,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

String _formatCategory(BuildContext context, String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.isEmpty) return 'Member';
  if (normalized == 'male') {
    return context.t('common.male', fallback: 'Male');
  }
  if (normalized == 'female') {
    return context.t('common.female', fallback: 'Female');
  }
  if (normalized == 'individual') {
    return context.t('common.individual', fallback: 'Individual');
  }
  if (normalized == 'married') {
    return context.t('common.married', fallback: 'Married');
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
