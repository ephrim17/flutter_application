import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchPhoneCall(
  BuildContext context,
  String phoneNumber,
) async {
  final normalized = phoneNumber.trim();
  if (normalized.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.phone_in_talk_rounded),
      title: Text(
        context.t(
          'common.call_confirmation_title',
          fallback: 'Call this number?',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t(
              'common.call_confirmation_message',
              fallback: 'Your phone app will open with this number.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SelectableText(
            normalized,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            context.t(
              'common.cancel',
              fallback: 'Cancel',
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            context.t(
              'common.call',
              fallback: 'Call',
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final uri = Uri.parse('tel:$normalized');
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(
            'common.phone_call_failed',
            fallback: 'Unable to place the call',
          ),
        ),
      ),
    );
  }
}
