import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/screens/side_drawer/about_screen/about_screen_view_state.dart';
import 'package:flutter_application/church_app/screens/side_drawer/about_screen/about_screen_viewmodel.dart';
import 'package:flutter_application/church_app/screens/side_drawer/pastor_section.dart';
import 'package:flutter_application/church_app/widgets/footer_contacts_widget.dart';
import 'package:flutter_application/church_app/widgets/footer_socials_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

part 'about_screen_views.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aboutStateAsync = ref.watch(aboutScreenStateProvider);

    return Scaffold(
      appBar: AppBar(),
      body: aboutStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "${context.t('common.error_prefix', fallback: 'Error')}: $e",
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (state) {
          if (state == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.t(
                    'about.empty_error',
                    fallback: 'About content is not available yet.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AboutHeroCard(state: state),
                const SizedBox(height: 20),
                _AboutNarrativeCard(text: state.description),
                const SizedBox(height: 24),
                _AboutSectionHeading(
                  eyebrow:
                      context.t('about.our_mission', fallback: 'Our Mission'),
                  title: 'What guides how we serve.',
                ),
                const SizedBox(height: 14),
                _AboutInsightCard(
                  icon: Icons.church_outlined,
                  title: context.t(
                    'about.our_mission',
                    fallback: 'Our Mission',
                  ),
                  description: state.mission,
                ),
                const SizedBox(height: 14),
                _AboutInsightCard(
                  icon: Icons.groups_2_outlined,
                  title: context.t(
                    'about.our_community',
                    fallback: 'Our Community',
                  ),
                  description: state.community,
                ),
                const SizedBox(height: 14),
                _AboutInsightCard(
                  icon: Icons.favorite_outline,
                  title: context.t(
                    'about.our_values',
                    fallback: 'Our Values',
                  ),
                  description: state.values,
                ),
                const SizedBox(height: 28),
                _AboutSectionHeading(
                  eyebrow: 'Leadership',
                  title: 'Meet the people caring for this church family.',
                ),
                const SizedBox(height: 14),
                const PastorWidget(),
                const SizedBox(height: 28),
                _AboutSectionHeading(
                  eyebrow: 'Stay Connected',
                  title:
                      'Reach out, follow along, and stay part of the community.',
                ),
                const SizedBox(height: 14),
                const _AboutFooterSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}
