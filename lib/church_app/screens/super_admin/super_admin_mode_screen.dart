import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuperAdminModeScreen extends ConsumerWidget {
  const SuperAdminModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t(
            'super_admin.choose_flow_title',
            fallback: 'Choose your flow',
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
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: carouselBoxDecoration(context),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(
                              'super_admin.choose_flow_title',
                              fallback: 'Choose your flow',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.t(
                              'super_admin.choose_flow_subtitle',
                              fallback:
                                  'You have super admin access. Continue with the normal church flow or open the super admin space.',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 22),
                          SolidButton(
                            label: context.t(
                              'super_admin.normal_flow',
                              fallback: 'Normal Flow',
                            ),
                            onPressed: () async {
                              await ref
                                  .read(superAdminEntryModeProvider.notifier)
                                  .setMode(SuperAdminEntryMode.normal);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'super_admin.normal_flow_desc',
                              fallback:
                                  'Go to church selection and continue like a regular signed-in user.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(superAdminEntryModeProvider.notifier)
                                  .setMode(SuperAdminEntryMode.superAdmin);
                            },
                            child: Text(
                              context.t(
                                'super_admin.super_flow',
                                fallback: 'Super Admin Flow',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.t(
                              'super_admin.super_flow_desc',
                              fallback:
                                  'Open the platform-level church management dashboard.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
