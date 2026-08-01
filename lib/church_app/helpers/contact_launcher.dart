import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExternalActionType { phone, email, map, other }

ExternalActionType externalActionTypeForUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'tel') return ExternalActionType.phone;
  if (scheme == 'mailto') return ExternalActionType.email;
  if (scheme == 'geo') return ExternalActionType.map;

  if (scheme == 'http' || scheme == 'https') {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isMapHost = host == 'maps.app.goo.gl' ||
        host == 'maps.google.com' ||
        host.startsWith('maps.google.') ||
        (host.contains('google.') && path.contains('/maps')) ||
        (host.contains('apple.com') && path.contains('/maps')) ||
        (host == 'goo.gl' && path.startsWith('/maps'));
    if (isMapHost) return ExternalActionType.map;
  }

  return ExternalActionType.other;
}

Future<bool> launchExternalUri(
  BuildContext context,
  Uri uri, {
  String? failureMessage,
}) async {
  final actionType = externalActionTypeForUri(uri);
  if (actionType != ExternalActionType.other) {
    final confirmed = await _confirmExternalAction(context, uri, actionType);
    if (confirmed != true || !context.mounted) return false;
  }

  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failureMessage ?? _failureMessage(context, actionType),
        ),
      ),
    );
  }
  return launched;
}

Future<void> launchPhoneCall(
  BuildContext context,
  String phoneNumber,
) async {
  final normalized = phoneNumber.trim();
  if (normalized.isEmpty) return;
  await launchExternalUri(
    context,
    Uri(scheme: 'tel', path: normalized),
    failureMessage: context.t('common.phone_call_failed'),
  );
}

Future<void> launchEmail(
  BuildContext context,
  String email, {
  String? subject,
  String? body,
}) async {
  final normalized = email.trim();
  if (normalized.isEmpty) return;
  await launchExternalUri(
    context,
    Uri(
      scheme: 'mailto',
      path: normalized,
      queryParameters: {
        if ((subject ?? '').trim().isNotEmpty) 'subject': subject!.trim(),
        if ((body ?? '').trim().isNotEmpty) 'body': body!.trim(),
      },
    ),
  );
}

Future<void> launchMapLocation(
  BuildContext context,
  String locationOrUrl,
) async {
  final normalized = locationOrUrl.trim();
  if (normalized.isEmpty) return;
  final suppliedUri = Uri.tryParse(normalized);
  final uri = suppliedUri != null &&
          (suppliedUri.scheme == 'http' ||
              suppliedUri.scheme == 'https' ||
              suppliedUri.scheme == 'geo')
      ? suppliedUri
      : Uri.https(
          'www.google.com',
          '/maps/search/',
          {'api': '1', 'query': normalized},
        );
  await launchExternalUri(context, uri);
}

Future<bool?> _confirmExternalAction(
  BuildContext context,
  Uri uri,
  ExternalActionType actionType,
) {
  final copy = _confirmationCopy(context, uri, actionType);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(copy.icon),
      title: Text(copy.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(copy.message, textAlign: TextAlign.center),
          if (copy.detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              copy.detail,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(copy.confirmLabel),
        ),
      ],
    ),
  );
}

_ExternalConfirmationCopy _confirmationCopy(
  BuildContext context,
  Uri uri,
  ExternalActionType actionType,
) {
  switch (actionType) {
    case ExternalActionType.phone:
      return _ExternalConfirmationCopy(
        icon: Icons.phone_in_talk_rounded,
        title: context.t('common.call_confirmation_title'),
        message: context.t('common.call_confirmation_message'),
        detail: Uri.decodeComponent(uri.path),
        confirmLabel: context.t('common.call'),
      );
    case ExternalActionType.email:
      return _ExternalConfirmationCopy(
        icon: Icons.outgoing_mail,
        title: context.t('common.email_confirmation_title'),
        message: context.t('common.email_confirmation_message'),
        detail: Uri.decodeComponent(uri.path),
        confirmLabel: context.t('common.open_email'),
      );
    case ExternalActionType.map:
      final query = uri.queryParameters['query']?.trim() ?? '';
      return _ExternalConfirmationCopy(
        icon: Icons.map_outlined,
        title: context.t('common.map_confirmation_title'),
        message: context.t('common.map_confirmation_message'),
        detail: query,
        confirmLabel: context.t('common.open_maps'),
      );
    case ExternalActionType.other:
      throw StateError('A generic link does not require confirmation copy.');
  }
}

String _failureMessage(
  BuildContext context,
  ExternalActionType actionType,
) {
  return switch (actionType) {
    ExternalActionType.phone => context.t('common.phone_call_failed'),
    ExternalActionType.email => context.t('common.email_open_failed'),
    ExternalActionType.map => context.t('common.map_open_failed'),
    ExternalActionType.other => context.t('common.open_link_failed'),
  };
}

class _ExternalConfirmationCopy {
  const _ExternalConfirmationCopy({
    required this.icon,
    required this.title,
    required this.message,
    required this.detail,
    required this.confirmLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String detail;
  final String confirmLabel;
}
