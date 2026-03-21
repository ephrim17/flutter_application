import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show churchesProvider;
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/screens/entry/create_auth_account_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/modals/today_birthdays_modal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final currentChurchIdAsync = ref.watch(currentChurchIdProvider);
    final selectedChurch = ref.watch(selectedChurchProvider);
    final churchesAsync = ref.watch(churchesProvider);
    final currentChurchId = currentChurchIdAsync.asData?.value;
    final availableChurches = churchesAsync.asData?.value ?? const <Church>[];
    final currentChurch = selectedChurch ??
        (currentChurchId == null
            ? null
            : availableChurches.cast<Church?>().firstWhere(
                  (church) => church?.id == currentChurchId,
                  orElse: () => null,
                ));
    final allMembers = membersAsync.asData?.value ?? const <AppUser>[];
    final todayBirthdays = allMembers
        .where((member) => _isBirthdayToday(member.dob))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: AppBarTitle(
            text: context.t('members.title', fallback: 'Members'),
          ),
          actions: [
            if (isAdmin && currentChurch != null)
              IconButton(
                tooltip: context.t(
                  'members.create_member',
                  fallback: 'Create Member',
                ),
                onPressed: () => _showCreateMemberOptions(currentChurch),
                icon: const Icon(Icons.person_add_alt_1),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'All'),
              const Tab(text: 'Families'),
              const Tab(text: 'Individuals'),
              Tab(
                child: _BirthdayTabLabel(
                  count: todayBirthdays.length,
                ),
              ),
            ],
          ),
        ),
        body: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              context.t('members.error_loading',
                  fallback: 'Error loading members'),
            ),
          ),
          data: (members) {
            if (members.isEmpty) {
              return Center(
                child: Text(
                  context.t('members.none', fallback: 'No members found'),
                ),
              );
            }

            final sortedMembers = [...members]..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            final filteredMembers = _filterMembers(sortedMembers, _query);
            final familyMembers = filteredMembers
                .where((member) => member.category.toLowerCase() == 'family')
                .toList();
            final individualMembers = filteredMembers
                .where(
                    (member) => member.category.toLowerCase() == 'individual')
                .toList();
            final groupedFamilies = _groupFamilies(familyMembers);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search members, family ID, email or phone',
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CountChip(
                              label: 'All', count: filteredMembers.length),
                          _CountChip(
                              label: 'Families', count: groupedFamilies.length),
                          _CountChip(
                              label: 'Individuals',
                              count: individualMembers.length),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _MembersListView(
                        members: filteredMembers,
                        isAdmin: isAdmin,
                        currentUid: currentUid,
                      ),
                      _FamilyGroupsView(
                        groups: groupedFamilies,
                        isAdmin: isAdmin,
                        currentUid: currentUid,
                      ),
                      _MembersListView(
                        members: individualMembers,
                        isAdmin: isAdmin,
                        currentUid: currentUid,
                      ),
                      _MembersListView(
                        members: todayBirthdays,
                        isAdmin: isAdmin,
                        currentUid: currentUid,
                        emptyMessage: 'No birthdays today',
                        showBirthdayAction: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateMemberOptions(Church selectedChurch) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Create with email'),
                  subtitle: const Text(
                    'Create Church Connect account first, then complete member details.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateAuthAccountScreen(
                          adminCreateMode: true,
                          churchId: selectedChurch.id,
                          churchName: selectedChurch.name,
                          churchLogo: selectedChurch.logo,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Create without email'),
                  subtitle: const Text(
                    'Add the member directly using church details only.',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => LoginRequestScreen(
                          churchId: selectedChurch.id,
                          churchName: selectedChurch.name,
                          churchLogo: selectedChurch.logo,
                          adminCreateMode: true,
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
    );
  }
}

class _MembersListView extends StatelessWidget {
  const _MembersListView({
    required this.members,
    required this.isAdmin,
    required this.currentUid,
    this.emptyMessage = 'No matching members',
    this.showBirthdayAction = false,
  });

  final List<AppUser> members;
  final bool isAdmin;
  final String? currentUid;
  final String emptyMessage;
  final bool showBirthdayAction;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        return _MemberTile(
          member: members[index],
          isAdmin: isAdmin,
          currentUid: currentUid,
          showBirthdayAction: showBirthdayAction,
        );
      },
    );
  }
}

class _BirthdayTabLabel extends StatelessWidget {
  const _BirthdayTabLabel({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Birthdays'),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FamilyGroupsView extends StatelessWidget {
  const _FamilyGroupsView({
    required this.groups,
    required this.isAdmin,
    required this.currentUid,
  });

  final List<MapEntry<String, List<AppUser>>> groups;
  final bool isAdmin;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(child: Text('No family groups found'));
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final members = entry.value;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ExpansionTile(
            title: Text(_formatFamilyHeader(entry.key)),
            subtitle: Text('${members.length} member(s)'),
            children: members
                .map(
                  (member) => _MemberTile(
                    member: member,
                    isAdmin: isAdmin,
                    currentUid: currentUid,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.isAdmin,
    required this.currentUid,
    this.showBirthdayAction = false,
  });

  final AppUser member;
  final bool isAdmin;
  final String? currentUid;
  final bool showBirthdayAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailing = showBirthdayAction
        ? TextButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.95,
                  child: BirthdayPostComposerModal(member: member),
                ),
              );
            },
            child: Text(
              context.t('common.send', fallback: 'Send'),
            ),
          )
        : (isAdmin && member.uid != currentUid)
            ? Switch(
                value: member.approved,
                onChanged: (val) async {
                  final churchId = await ref.read(currentChurchIdProvider.future);
                  if (churchId == null) return;

                  final repo = MembersRepository(
                    firestore: ref.read(firestoreProvider),
                    churchId: churchId,
                  );

                  await repo.approveMember(member.uid, val);
                },
              )
            : null;

    return ListTile(
      onTap: () => _showMemberDetailsSheet(
        context,
        ref,
        member,
        isAdmin: isAdmin,
        currentUid: currentUid,
      ),
      leading: CircleAvatar(
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
        ),
      ),
      title: Text(member.name),
      trailing: trailing,
    );
  }
}

Future<void> _showMemberDetailsSheet(
  BuildContext context,
  WidgetRef ref,
  AppUser member, {
  required bool isAdmin,
  required String? currentUid,
}) {
  final theme = Theme.of(context);
  final canDelete = isAdmin && member.uid != currentUid;
  final canEditMember = isAdmin && member.uid != currentUid;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _valueOrFallback(member.name),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCategory(member.category),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _MemberDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: _valueOrFallback(member.address),
              ),
              _MemberDetailRow(
                icon: Icons.cake_outlined,
                label: 'DOB',
                value: _formatDob(member.dob),
              ),
              _MemberDetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _valueOrFallback(member.email),
              ),
              _MemberDetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _valueOrFallback(member.phone),
                onActionTap: member.phone.trim().isEmpty
                    ? null
                    : () => launchPhoneCall(context, member.phone),
              ),
              if (canEditMember) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selectedChurch = ref.read(selectedChurchProvider);
                      final currentChurchId =
                          await ref.read(currentChurchIdProvider.future);
                      final availableChurches =
                          ref.read(churchesProvider).asData?.value ??
                              const <Church>[];
                      final currentChurch = selectedChurch ??
                          (currentChurchId == null
                              ? null
                              : availableChurches.cast<Church?>().firstWhere(
                                    (church) => church?.id == currentChurchId,
                                    orElse: () => null,
                                  ));

                      if (currentChurch == null || !context.mounted) return;
                      final shouldCreateLoginFirst = member.email.trim().isEmpty
                          ? await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text(
                                      'Create Church Connect account?',
                                    ),
                                    content: const Text(
                                      'This member does not have a Church Connect account yet. Do you want to create it first?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        child: const Text('No'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(true),
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                                ) ??
                              false
                          : false;
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      if (shouldCreateLoginFirst) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreateAuthAccountScreen(
                              adminCreateMode: true,
                              churchId: currentChurch.id,
                              churchName: currentChurch.name,
                              churchLogo: currentChurch.logo,
                              existingMember: member,
                              continueToEditAfterCreate: true,
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoginRequestScreen(
                            churchId: currentChurch.id,
                            churchName: currentChurch.name,
                            churchLogo: currentChurch.logo,
                            adminCreateMode: true,
                            existingMember: member,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      context.t(
                        'members.edit_member',
                        fallback: 'Edit Member',
                      ),
                    ),
                  ),
                ),
              ],
              if (canDelete) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(
                            context.t(
                              'members.delete_title',
                              fallback: 'Delete member?',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          content: Text(
                            context.t(
                              'members.delete_message',
                              fallback:
                                  'This will remove the member from this church.',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text(
                                context.t(
                                  'settings.cancel',
                                  fallback: 'Cancel',
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                              ),
                              child: Text(
                                context.t(
                                  'common.delete',
                                  fallback: 'Delete',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (shouldDelete != true) return;

                      final churchId =
                          await ref.read(currentChurchIdProvider.future);
                      if (churchId == null) return;

                      final repo = MembersRepository(
                        firestore: ref.read(firestoreProvider),
                        churchId: churchId,
                      );

                      await repo.deleteMember(member.uid);

                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t(
                              'members.delete_success',
                              fallback: 'Member deleted',
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      context.t(
                        'common.delete',
                        fallback: 'Delete',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count'),
    );
  }
}

List<AppUser> _filterMembers(List<AppUser> members, String query) {
  if (query.isEmpty) return members;

  return members.where((member) {
    final haystacks = [
      member.name,
      member.email,
      member.phone,
      member.familyId,
      member.category,
    ].map((value) => value.toLowerCase());

    return haystacks.any((value) => value.contains(query));
  }).toList();
}

List<MapEntry<String, List<AppUser>>> _groupFamilies(List<AppUser> members) {
  final grouped = <String, List<AppUser>>{};

  for (final member in members) {
    final familyId = member.familyId.trim().isEmpty
        ? 'No Family ID'
        : member.familyId.trim();
    grouped.putIfAbsent(familyId, () => []).add(member);
  }

  final entries = grouped.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  for (final entry in entries) {
    entry.value
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  return entries;
}

String _formatFamilyHeader(String familyId) {
  final normalized = familyId.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'no family id') {
    return 'Unknown family';
  }

  var cleaned = normalized
      .replaceFirst(RegExp(r'^family_'), '')
      .replaceFirst(RegExp(r'^individual_'), '');

  final parts = cleaned.split('_').where((part) => part.isNotEmpty).toList();
  if (parts.length > 1) {
    parts.removeLast();
  }

  final displayName = parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ')
      .trim();

  if (displayName.isEmpty) {
    return 'Unknown family';
  }

  final suffix = displayName.endsWith('s') ? "'" : "'s";
  return '$displayName$suffix family';
}

class _MemberDetailRow extends StatelessWidget {
  const _MemberDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onActionTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onActionTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              onActionTap != null ? Icons.call_outlined : icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDob(DateTime? date) {
  if (date == null) return 'Not provided';
  return DateFormat('dd MMM yyyy').format(date);
}

bool _isBirthdayToday(DateTime? dob) {
  if (dob == null) return false;
  final now = DateTime.now();
  return dob.day == now.day && dob.month == now.month;
}

String _formatCategory(String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.isEmpty) return 'Not provided';
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _valueOrFallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not provided' : trimmed;
}
