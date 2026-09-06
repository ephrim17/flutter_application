import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';

/// Shows a confirmation dialog with consistent, theme-independent button
/// sizing. AlertDialog actions capture the ambient theme of the calling
/// route (the same mechanism used by showModalBottomSheet), so a screen
/// that styles its own full-width FilledButtons for forms would otherwise
/// make this dialog's confirm button balloon to full width while Cancel
/// stays text-sized. Explicit sizing here keeps both buttons compact and
/// visually balanced regardless of where the dialog is shown from.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  final theme = Theme.of(context);
  final compactStyle = FilledButton.styleFrom(
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    backgroundColor: isDestructive ? theme.colorScheme.error : null,
    foregroundColor: isDestructive ? theme.colorScheme.onError : null,
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel ?? dialogContext.t('common.cancel')),
        ),
        FilledButton(
          style: compactStyle,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel ?? dialogContext.t('common.delete')),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
