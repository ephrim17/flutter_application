import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
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
  bool showCategory = true,
  bool showAddress = true,
  bool showDob = true,
  bool showEmail = true,
  bool showPhone = true,
}) {
  final theme = Theme.of(context);
  final subtitle = showCategory ? _formatCategory(context, user.category) : '';

  return showAppModalBottomSheet<void>(
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
                  AppProfileAvatar(
                    name: user.name,
                    imageUrl: user.profilePhotoUrl,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _valueOrFallback(context, user.name),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
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
              if ((churchName ?? '').trim().isNotEmpty)
                _UserDetailRow(
                  icon: Icons.church_outlined,
                  label: context.t('members.church_label'),
                  value: _valueOrFallback(context, churchName ?? ''),
                ),
              if ((churchPastorName ?? '').trim().isNotEmpty)
                _UserDetailRow(
                  icon: Icons.person_outline,
                  label: context.t('members.church_pastor_label'),
                  value: _valueOrFallback(context, churchPastorName ?? ''),
                ),
              if (showAddress)
                _UserDetailRow(
                  icon: Icons.location_on_outlined,
                  label: context.t('members.address_label'),
                  value: _valueOrFallback(context, user.address),
                ),
              if (showDob)
                _UserDetailRow(
                  icon: Icons.cake_outlined,
                  label: context.t('members.date_of_birth_label'),
                  value: _formatDob(context, user.dob),
                ),
              if (showEmail)
                _UserDetailRow(
                  icon: Icons.email_outlined,
                  label: context.t('members.email_label'),
                  value: _valueOrFallback(context, user.email),
                ),
              if (showPhone)
                _UserDetailRow(
                  icon: Icons.phone_outlined,
                  label: context.t('members.phone_label'),
                  value: _valueOrFallback(context, user.phone),
                  onActionTap: user.phone.trim().isEmpty
                      ? null
                      : () => launchPhoneCall(context, user.phone),
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
    this.onActionTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onActionTap == null)
            SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            )
          else
            Tooltip(
              message: context.t('ui.user_quick_card.call'),
              child: InkResponse(
                onTap: onActionTap,
                radius: 22,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
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
    );
  }
}

String _formatDob(BuildContext context, DateTime? date) {
  if (date == null) return context.t('common.not_provided');
  return DateFormat('dd MMM yyyy').format(date);
}

String _formatCategory(BuildContext context, String category) {
  final normalized = category.trim().toLowerCase();
  if (normalized.isEmpty) return context.t('common.not_provided');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _valueOrFallback(BuildContext context, String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? context.t('common.not_provided') : trimmed;
}
