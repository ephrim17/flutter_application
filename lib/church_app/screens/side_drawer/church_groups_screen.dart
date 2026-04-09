import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const _pastorsGroupId = 'pastors';
  static const _financeGroupId = 'finance';

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
    final isAdmin = ref.read(isAdminProvider);
    final currentUser = ref.read(appUserProvider).value;
    if (!_canManageGroupMembership(
      group: group,
      isAdmin: isAdmin,
      currentUser: currentUser,
    )) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            group.id == _financeGroupId
                ? 'Only admins in the Pastors group can manage Finance members.'
                : 'You do not have permission to manage this group.',
          ),
        ),
      );
      return;
    }

    final repo = await _membersRepository();
    if (repo == null) return;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: SafeArea(
            child: _AddGroupMembersSheet(
              group: group,
              repository: repo,
              onAddMember: (member) async {
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

  Future<void> _showGroupPickerSheet(
    BuildContext context,
    List<ChurchGroupDefinition> groups,
  ) async {
    final selectedGroup = await showModalBottomSheet<ChurchGroupDefinition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GroupPickerSheet(
        groups: groups,
        selectedGroupId: groups[_tabController.index].id,
      ),
    );

    if (selectedGroup == null || !mounted) return;
    final nextIndex = groups.indexWhere((item) => item.id == selectedGroup.id);
    if (nextIndex < 0 || nextIndex == _tabController.index) return;
    _tabController.animateTo(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final currentUser = ref.watch(appUserProvider).value;
    final visibleGroups = isAdmin
        ? churchGroupDefinitions
        : churchGroupDefinitions
            .where(
              (group) =>
                  currentUser?.churchGroupIds.contains(group.id) ?? false,
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
    final canManageCurrentGroup = _canManageGroupMembership(
      group: currentGroup,
      isAdmin: isAdmin,
      currentUser: currentUser,
    );

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('groups.title', fallback: 'Church Groups'),
        ),
        actions: [
          if (canManageCurrentGroup)
            IconButton(
              tooltip: context
                  .t('groups.add_to_group', fallback: 'Add to {group}')
                  .replaceAll('{group}', currentGroup.label),
              onPressed: () => _showAddMembersSheet(context, currentGroup),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: _GroupOverviewCard(
              currentGroup: currentGroup,
              totalGroupCount: visibleGroups.length,
              onOpenAllGroups: () =>
                  _showGroupPickerSheet(context, visibleGroups),
            ),
          ),
          Expanded(
            child: _GroupMembersTab(
              group: currentGroup,
              onMemberTap: _canManageGroupMembership(
                group: currentGroup,
                isAdmin: isAdmin,
                currentUser: currentUser,
              )
                  ? (member) =>
                      _showMemberActionsSheet(context, member, currentGroup)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  bool _canManageGroupMembership({
    required ChurchGroupDefinition group,
    required bool isAdmin,
    required AppUser? currentUser,
  }) {
    if (!isAdmin) return false;
    if (group.id != _financeGroupId) return true;
    return currentUser?.churchGroupIds.contains(_pastorsGroupId) ?? false;
  }
}

class _AddGroupMembersSheet extends StatefulWidget {
  const _AddGroupMembersSheet({
    required this.group,
    required this.repository,
    required this.onAddMember,
  });

  final ChurchGroupDefinition group;
  final MembersRepository repository;
  final Future<void> Function(AppUser member) onAddMember;

  @override
  State<_AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<_AddGroupMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<AppUser> _members = <AppUser>[];
  final Set<String> _memberIds = <String>{};
  final Set<String> _busyMemberIds = <String>{};
  Timer? _debounce;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _query = '';
  DocumentSnapshot<AppUser>? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadMembers(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers({required bool reset}) async {
    if (_isLoadingMore) return;

    if (reset) {
      setState(() {
        _isLoading = true;
        _hasMore = true;
        _lastDocument = null;
        _members.clear();
        _memberIds.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      var page = await widget.repository.fetchMembersPage(
        query: _query,
        startAfter: reset ? null : _lastDocument,
      );

      final nextMembers = <AppUser>[];
      while (true) {
        for (final member in page.members) {
          if (member.churchGroupIds.contains(widget.group.id)) {
            continue;
          }
          if (_memberIds.add(member.uid)) {
            nextMembers.add(member);
          }
        }

        final enoughResults = nextMembers.length >= 12 || !page.hasMore;
        if (enoughResults) {
          _lastDocument = page.lastDocument;
          _hasMore = page.hasMore;
          break;
        }

        page = await widget.repository.fetchMembersPage(
          query: _query,
          startAfter: page.lastDocument,
        );
      }

      if (!mounted) return;
      setState(() {
        _members.addAll(nextMembers);
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
      });
      _loadMembers(reset: true);
    });
  }

  Future<void> _handleAdd(AppUser member) async {
    setState(() {
      _busyMemberIds.add(member.uid);
    });
    try {
      await widget.onAddMember(member);
    } finally {
      if (mounted) {
        setState(() {
          _busyMemberIds.remove(member.uid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context
                .t('groups.add_to_group', fallback: 'Add to {group}')
                .replaceAll('{group}', widget.group.label),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search by name, email, or phone. Members already in this group are hidden for faster selection.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search members',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: carouselBoxDecoration(context),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No available members found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _query.isEmpty
                                  ? context.t(
                                      'groups.all_members_assigned',
                                      fallback:
                                          'All members are already assigned to this group.',
                                    )
                                  : 'Try a different search term.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _members.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= _members.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: _isLoadingMore
                                      ? null
                                      : () => _loadMembers(reset: false),
                                  icon: _isLoadingMore
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    _isLoadingMore
                                        ? 'Loading more...'
                                        : 'Load more',
                                  ),
                                ),
                              ),
                            );
                          }

                          final member = _members[index];
                          final isBusy = _busyMemberIds.contains(member.uid);
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
                              title: Text(
                                member.name.trim().isEmpty
                                    ? 'Unnamed member'
                                    : member.name,
                              ),
                              subtitle: Text(
                                [
                                  if (member.phone.trim().isNotEmpty)
                                    member.phone,
                                  if (member.email.trim().isNotEmpty)
                                    member.email,
                                ].join(' • '),
                              ),
                              trailing: FilledButton.tonalIcon(
                                onPressed:
                                    isBusy ? null : () => _handleAdd(member),
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded),
                                label: const Text('Add'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _GroupOverviewCard extends ConsumerWidget {
  const _GroupOverviewCard({
    required this.currentGroup,
    required this.totalGroupCount,
    required this.onOpenAllGroups,
  });

  final ChurchGroupDefinition currentGroup;
  final int totalGroupCount;
  final VoidCallback onOpenAllGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(churchGroupMembersProvider(currentGroup.id));
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: carouselBoxDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Group',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.66),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentGroup.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenAllGroups,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          membersAsync.when(
            loading: () => const SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              context.t(
                'groups.group_load_failed',
                fallback: 'Unable to load this group right now.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            data: (members) => Text(
              '${members.length} member${members.length == 1 ? '' : 's'} in this group',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Browsing 1 of $totalGroupCount groups. Use Change to open the full list.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.74),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupPickerSheet extends StatefulWidget {
  const _GroupPickerSheet({
    required this.groups,
    required this.selectedGroupId,
  });

  final List<ChurchGroupDefinition> groups;
  final String selectedGroupId;

  @override
  State<_GroupPickerSheet> createState() => _GroupPickerSheetState();
}

class _GroupPickerSheetState extends State<_GroupPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredGroups = widget.groups.where((group) {
      return group.label.toLowerCase().contains(_query.toLowerCase());
    }).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Browse Groups',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a group from one simple list.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search groups',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Text(
                      'No groups match your search.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      final isSelected = group.id == widget.selectedGroupId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(cornerRadius),
                          onTap: () => Navigator.of(context).pop(group),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: carouselBoxDecoration(context),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.label,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.colorScheme.primary,
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
                    ? (onMemberTap == null
                        ? null
                        : const Icon(Icons.more_horiz))
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
