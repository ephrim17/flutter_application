import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/user_quick_card_widget.dart';

class DashboardGenderMembersScreen extends StatefulWidget {
  const DashboardGenderMembersScreen({
    super.key,
    required this.gender,
    required this.color,
    required this.members,
  });

  final String gender;
  final Color color;
  final List<AppUser> members;

  @override
  State<DashboardGenderMembersScreen> createState() =>
      _DashboardGenderMembersScreenState();
}

class _DashboardGenderMembersScreenState
    extends State<DashboardGenderMembersScreen> {
  String _query = '';

  List<AppUser> get _visibleMembers {
    final gender = widget.gender.trim().toLowerCase();
    final query = _query.trim().toLowerCase();
    final filtered = widget.members.where((member) {
      if (member.gender.trim().toLowerCase() != gender) return false;
      if (query.isEmpty) return true;
      return [
        member.name,
        member.email,
        member.phone,
        member.familyId,
        member.category,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = _visibleMembers;
    final total = widget.members
        .where(
          (member) =>
              member.gender.trim().toLowerCase() ==
              widget.gender.trim().toLowerCase(),
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t(
            'dashboard.gender_members_title',
            parameters: {'gender': widget.gender},
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: widget.color.withValues(alpha: 0.16),
                          foregroundColor: widget.color,
                          child: const Icon(Icons.people_alt_rounded),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.gender,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.t(
                                  'dashboard.gender_member_count',
                                  parameters: {
                                    'count': total,
                                    'memberLabel': context.t(
                                      total == 1
                                          ? 'dashboard.member_singular'
                                          : 'dashboard.member_plural',
                                    ),
                                  },
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    hintText: context.t(
                      'dashboard.search_gender_members',
                      parameters: {
                        'gender': widget.gender.toLowerCase(),
                      },
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: members.isEmpty
                  ? _GenderMembersEmptyState(
                      hasQuery: _query.trim().isNotEmpty,
                      gender: widget.gender,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final secondary = member.email.trim().isNotEmpty
                            ? member.email.trim()
                            : member.phone.trim().isNotEmpty
                                ? member.phone.trim()
                                : _formatCategory(context, member.category);
                        return Material(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => showUserQuickCard(context, member),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  AppProfileAvatar(
                                    name: member.name,
                                    imageUrl: member.profilePhotoUrl,
                                    radius: 23,
                                    borderColor:
                                        widget.color.withValues(alpha: 0.24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name.trim().isEmpty
                                              ? context.t(
                                                  'dashboard.member_fallback',
                                                )
                                              : member.name.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          secondary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
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
      ),
    );
  }
}

class _GenderMembersEmptyState extends StatelessWidget {
  const _GenderMembersEmptyState({
    required this.hasQuery,
    required this.gender,
  });

  final bool hasQuery;
  final String gender;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.group_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? context.t('dashboard.no_gender_search_results')
                  : context.t(
                      'dashboard.no_gender_members',
                      parameters: {'gender': gender},
                    ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCategory(BuildContext context, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return context.t('dashboard.church_member_fallback');
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
