import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchPhoneCall(
  BuildContext context,
  String phoneNumber,
) async {
  final normalized = phoneNumber.trim();
  if (normalized.isEmpty) return;

  final uri = Uri.parse('tel:$normalized');
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to place the call')),
    );
  }
}
