import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:intl/intl.dart';

Future<void> showUserQuickCard(BuildContext context, AppUser user) {
  return showUserQuickCardWithChurch(context, user);
}

Future<void> showUserQuickCardWithChurch(
  BuildContext context,
  AppUser user, {
  String? churchName,
  String? churchPastorName,
}) {
  final theme = Theme.of(context);

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
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _valueOrFallback(user.name),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCategory(user.category),
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
              _UserDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: _valueOrFallback(user.address),
              ),
              if ((churchName ?? '').trim().isNotEmpty)
                _UserDetailRow(
                  icon: Icons.church_outlined,
                  label: 'Church',
                  value: _valueOrFallback(churchName ?? ''),
                ),
              if ((churchPastorName ?? '').trim().isNotEmpty)
                _UserDetailRow(
                  icon: Icons.person_outline,
                  label: 'Church Pastor',
                  value: _valueOrFallback(churchPastorName ?? ''),
                ),
              _UserDetailRow(
                icon: Icons.cake_outlined,
                label: 'DOB',
                value: _formatDob(user.dob),
              ),
              _UserDetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _valueOrFallback(user.email),
              ),
              _UserDetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _valueOrFallback(user.phone),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _UserDetailRow extends StatelessWidget {
  const _UserDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
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
    );
  }
}

String _formatDob(DateTime? date) {
  if (date == null) return 'Not provided';
  return DateFormat('dd MMM yyyy').format(date);
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
