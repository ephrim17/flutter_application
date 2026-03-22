import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
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
              Tab(text: context.t('members.all_tab', fallback: 'All')),
              Tab(
                text: context.t('members.families_tab', fallback: 'Families'),
              ),
              Tab(
                text: context.t(
                  'members.individuals_tab',
                  fallback: 'Individuals',
                ),
              ),
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
                          hintText: context.t(
                            'members.search_hint',
                            fallback:
                                'Search members, family ID, email or phone',
                          ),
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
                            label: context.t(
                              'members.all_tab',
                              fallback: 'All',
                            ),
                            count: filteredMembers.length,
                          ),
                          _CountChip(
                            label: context.t(
                              'members.families_tab',
                              fallback: 'Families',
                            ),
                            count: groupedFamilies.length,
                          ),
                          _CountChip(
                            label: context.t(
                              'members.individuals_tab',
                              fallback: 'Individuals',
                            ),
                            count: individualMembers.length,
                          ),
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
                        emptyMessage: context.t(
                          'members.no_birthdays_today',
                          fallback: 'No birthdays today',
                        ),
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
                  title: Text(
                    context.t(
                      'members.create_with_email',
                      fallback: 'Create with email',
                    ),
                  ),
                  subtitle: Text(
                    context.t(
                      'members.create_with_email_subtitle',
                      fallback:
                          'Create Church Connect account first, then complete member details.',
                    ),
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
                  title: Text(
                    context.t(
                      'members.create_without_email',
                      fallback: 'Create without email',
                    ),
                  ),
                  subtitle: Text(
                    context.t(
                      'members.create_without_email_subtitle',
                      fallback:
                          'Add the member directly using church details only.',
                    ),
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
    this.emptyMessage = '',
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
      return Center(
        child: Text(
          emptyMessage.isEmpty
              ? context.t(
                  'members.no_matching_members',
                  fallback: 'No matching members',
                )
              : emptyMessage,
        ),
      );
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
        Text(
          context.t('members.birthdays_tab', fallback: 'Birthdays'),
        ),
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
      return Center(
        child: Text(
          context.t(
            'members.no_family_groups_found',
            fallback: 'No family groups found',
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final entry = groups[index];
        final members = entry.value;

        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ExpansionTile(
            title: Text(_formatFamilyHeader(context, entry.key)),
            subtitle: Text(
              '${members.length} ${context.t('members.member_count_suffix', fallback: 'member(s)')}',
            ),
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
  final canEditMember = isAdmin;
  final canApproveMember = isAdmin && member.uid != currentUid;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final brightness = Theme.of(context).brightness;
      final dragHandleColor =
          brightness == Brightness.dark ? Colors.white : Colors.black;
      var approvedValue = member.approved;
      return Theme(
        data: Theme.of(context).copyWith(
          bottomSheetTheme: Theme.of(context).bottomSheetTheme.copyWith(
                dragHandleColor: dragHandleColor,
              ),
        ),
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setModalState) => SafeArea(
              child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
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
                          _valueOrFallback(context, member.name),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCategory(context, member.category),
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
              if (canApproveMember)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    context.t(
                      'members.approve_member',
                      fallback: 'Approve member',
                    ),
                  ),
                  subtitle: Text(
                    approvedValue
                        ? context.t('common.approved', fallback: 'Approved')
                        : context.t(
                            'common.pending_approval',
                            fallback: 'Pending approval',
                          ),
                  ),
                  value: approvedValue,
                  onChanged: (val) async {
                    final churchId =
                        await ref.read(currentChurchIdProvider.future);
                    if (churchId == null) return;

                    final repo = MembersRepository(
                      firestore: ref.read(firestoreProvider),
                      churchId: churchId,
                    );

                    await repo.approveMember(member.uid, val);
                    setModalState(() {
                      approvedValue = val;
                    });
                  },
                ),
              const SizedBox(height: 20),
              _MemberDetailSection(
                title: context.t(
                  'members.basic_details_title',
                  fallback: 'Basic Details',
                ),
                initiallyExpanded: true,
                child: Column(
                  children: [
                    _MemberDetailRow(
                      icon: Icons.badge_outlined,
                      label: context.t('members.name_label', fallback: 'Name'),
                      value: _valueOrFallback(context, member.name),
                    ),
                    _MemberDetailRow(
                      icon: Icons.phone_outlined,
                      label: context.t('members.phone_label', fallback: 'Phone'),
                      value: _valueOrFallback(context, member.phone),
                      onActionTap: member.phone.trim().isEmpty
                          ? null
                          : () => launchPhoneCall(context, member.phone),
                    ),
                    _MemberDetailRow(
                      icon: Icons.contact_phone_outlined,
                      label: context.t(
                        'members.contact_label',
                        fallback: 'Contact',
                      ),
                      value: _valueOrFallback(context, member.contact),
                    ),
                    _MemberDetailRow(
                      icon: Icons.person_outline,
                      label: context.t(
                        'members.gender_label',
                        fallback: 'Gender',
                      ),
                      value: _valueOrFallback(
                        context,
                        _formatCategory(context, member.gender),
                      ),
                    ),
                    _MemberDetailRow(
                      icon: Icons.email_outlined,
                      label: context.t('members.email_label', fallback: 'Email'),
                      value: _valueOrFallback(context, member.email),
                    ),
                    _MemberDetailRow(
                      icon: Icons.cake_outlined,
                      label: context.t(
                        'members.date_of_birth_label',
                        fallback: 'Date of Birth',
                      ),
                      value: _formatDob(context, member.dob),
                    ),
                    _MemberDetailRow(
                      icon: Icons.category_outlined,
                      label: context.t(
                        'members.category_label',
                        fallback: 'Category',
                      ),
                      value: _valueOrFallback(
                        context,
                        _formatCategory(context, member.category),
                      ),
                    ),
                    _MemberDetailRow(
                      icon: Icons.family_restroom_outlined,
                      label: context.t(
                        'members.family_id_label',
                        fallback: 'Family ID',
                      ),
                      value: _valueOrFallback(context, member.familyId),
                    ),
                    _MemberDetailRow(
                      icon: Icons.location_on_outlined,
                      label: context.t(
                        'members.address_label',
                        fallback: 'Address',
                      ),
                      value: _valueOrFallback(context, member.address),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                _MemberDetailSection(
                  title: context.t(
                    'members.extended_information_title',
                    fallback: 'Extended Information',
                  ),
                  child: Column(
                    children: [
                      _MemberDetailRow(
                        icon: Icons.favorite_border,
                        label: context.t(
                          'members.marital_status_label',
                          fallback: 'Marital Status',
                        ),
                        value: _valueOrFallback(
                          context,
                          _formatCategory(context, member.maritalStatus),
                        ),
                      ),
                      _MemberDetailRow(
                        icon: Icons.celebration_outlined,
                        label: context.t(
                          'members.wedding_day_label',
                          fallback: 'Wedding Day',
                        ),
                        value: _formatDob(context, member.weddingDay),
                      ),
                      _MemberDetailRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: context.t(
                          'members.financial_stability_label',
                          fallback: 'Financial Stability',
                        ),
                        value: member.financialStabilityRating == 0
                            ? context.t(
                                'members.financial_not_rated',
                                fallback: 'Not rated',
                              )
                            : '${member.financialStabilityRating}/5',
                      ),
                      _MemberDetailRow(
                        icon: Icons.volunteer_activism_outlined,
                        label: context.t(
                          'members.financial_support_required',
                          fallback: 'Financial Support Required',
                        ),
                        value: member.financialSupportRequired
                            ? context.t('common.yes', fallback: 'Yes')
                            : context.t('common.no', fallback: 'No'),
                      ),
                      _MemberDetailRow(
                        icon: Icons.school_outlined,
                        label: context.t(
                          'members.educational_qualification',
                          fallback: 'Educational Qualification',
                        ),
                        value: _valueOrFallback(
                          context,
                          member.educationalQualification,
                        ),
                      ),
                      _MemberDetailRow(
                        icon: Icons.auto_awesome_outlined,
                        label: context.t(
                          'members.talents_and_gifts',
                          fallback: 'Talents & Gifts',
                        ),
                        value: member.talentsAndGifts.isEmpty
                            ? context.t(
                                'common.not_provided',
                                fallback: 'Not provided',
                              )
                            : member.talentsAndGifts.join(', '),
                      ),
                    ],
                  ),
                ),
              if (isAdmin)
                _MemberDetailSection(
                  title: context.t(
                    'members.church_groups_title',
                    fallback: 'Church Groups',
                  ),
                  child: member.churchGroupIds.isEmpty
                      ? Text(
                          context.t(
                            'members.no_church_groups_assigned',
                            fallback: 'No church groups assigned',
                          ),
                          style: theme.textTheme.bodyMedium,
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: member.churchGroupIds
                              .map(
                                (groupId) => Chip(
                                  label: Text(churchGroupLabel(groupId)),
                                ),
                              )
                              .toList(),
                        ),
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
                                    title: Text(
                                      context.t(
                                        'members.create_church_connect_account',
                                        fallback:
                                            'Create Church Connect account?',
                                      ),
                                    ),
                                    content: Text(
                                      context.t(
                                        'members.create_church_connect_account_message',
                                        fallback:
                                            'This member does not have a Church Connect account yet. Do you want to create it first?',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        child: Text(
                                          context.t(
                                            'common.no',
                                            fallback: 'No',
                                          ),
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(true),
                                        child: Text(
                                          context.t(
                                            'common.yes',
                                            fallback: 'Yes',
                                          ),
                                        ),
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
            ),
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
      member.contact,
      member.familyId,
      member.category,
      member.maritalStatus,
      member.educationalQualification,
      member.talentsAndGifts.join(' '),
      member.churchGroupIds.map(churchGroupLabel).join(' '),
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

String _formatFamilyHeader(BuildContext context, String familyId) {
  final normalized = familyId.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'no family id') {
    return context.t('members.unknown_family', fallback: 'Unknown family');
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
    return context.t('members.unknown_family', fallback: 'Unknown family');
  }

  final suffix = displayName.endsWith('s') ? "'" : "'s";
  return '$displayName$suffix family';
}

class _MemberDetailSection extends StatelessWidget {
  const _MemberDetailSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            iconColor: theme.colorScheme.primary,
            collapsedIconColor: theme.colorScheme.primary,
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
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

String _formatDob(BuildContext context, DateTime? date) {
  if (date == null) {
    return context.t('common.not_provided', fallback: 'Not provided');
  }
  return DateFormat('dd MMM yyyy').format(date);
}

bool _isBirthdayToday(DateTime? dob) {
  if (dob == null) return false;
  final now = DateTime.now();
  return dob.day == now.day && dob.month == now.month;
}

String _formatCategory(BuildContext context, String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.isEmpty) {
    return context.t('common.not_provided', fallback: 'Not provided');
  }
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

String _valueOrFallback(BuildContext context, String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty
      ? context.t('common.not_provided', fallback: 'Not provided')
      : trimmed;
}
