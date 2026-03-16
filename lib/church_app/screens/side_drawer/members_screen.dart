import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: AppBarTitle(
            text: context.t('members.title', fallback: 'Members'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Families'),
              Tab(text: 'Individuals'),
            ],
          ),
        ),
        body: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Text(
              context.t('members.error_loading', fallback: 'Error loading members'),
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

            final sortedMembers = [...members]
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            final filteredMembers = _filterMembers(sortedMembers, _query);
            final familyMembers = filteredMembers
                .where((member) => member.category.toLowerCase() == 'family')
                .toList();
            final individualMembers = filteredMembers
                .where((member) => member.category.toLowerCase() == 'individual')
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
                          _CountChip(label: 'All', count: filteredMembers.length),
                          _CountChip(label: 'Families', count: groupedFamilies.length),
                          _CountChip(label: 'Individuals', count: individualMembers.length),
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
}

class _MembersListView extends StatelessWidget {
  const _MembersListView({
    required this.members,
    required this.isAdmin,
    required this.currentUid,
  });

  final List<AppUser> members;
  final bool isAdmin;
  final String? currentUid;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No matching members'));
    }

    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        return _MemberTile(
          member: members[index],
          isAdmin: isAdmin,
          currentUid: currentUid,
        );
      },
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
  });

  final AppUser member;
  final bool isAdmin;
  final String? currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
        ),
      ),
      title: Text(member.name),
      trailing: (isAdmin && member.uid != currentUid)
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
          : null,
    );
  }
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
    final familyId = member.familyId.trim().isEmpty ? 'No Family ID' : member.familyId.trim();
    grouped.putIfAbsent(familyId, () => []).add(member);
  }

  final entries = grouped.entries.toList()
    ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

  for (final entry in entries) {
    entry.value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
