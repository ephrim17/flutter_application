import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PendingApprovalWidget extends ConsumerWidget {
  const PendingApprovalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: "Approval Pending",),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_top,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your request is under review',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait until the admin approves your account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              /// 🔄 Refresh Button
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(appUserProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
