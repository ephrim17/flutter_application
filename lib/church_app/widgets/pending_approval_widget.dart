import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PendingApprovalWidget extends ConsumerWidget {
  const PendingApprovalWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t(
            'approval.pending_title',
            fallback: 'Approval Pending',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        solidBackground: true,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top_rounded,
                        size: 38,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.t(
                        'approval.waiting_title',
                        fallback: 'Your access is waiting for approval',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.t(
                        'approval.waiting_message',
                        fallback:
                            'If an admin turned access off for this church, you can refresh your status here or go back and choose another church so you are not blocked.',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SolidButton(
                      label: context.t(
                        'approval.refresh_status',
                        fallback: 'Refresh Status',
                      ),
                      onPressed: () {
                        ref.invalidate(appUserProvider);
                      },
                    ),
                    const SizedBox(height: 12),
                    SolidButton(
                      label: context.t(
                        'approval.choose_another_church',
                        fallback: 'Choose Another Church',
                      ),
                      onPressed: () async {
                        final storage = ChurchLocalStorage();
                        await storage.clearChurch();
                        ref.read(selectedChurchProvider.notifier).state = null;
                        ref.invalidate(currentChurchIdProvider);
                        ref.invalidate(appUserProvider);

                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const SelectChurchScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
