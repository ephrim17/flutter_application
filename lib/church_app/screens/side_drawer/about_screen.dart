import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/about_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/about_providers.dart';
import 'package:flutter_application/church_app/widgets/footer_contacts_widget.dart';
import 'package:flutter_application/church_app/widgets/footer_socials_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aboutAsync = ref.watch(aboutProvider);

    return Scaffold(
      appBar: AppBar(),
      body: aboutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (about) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildHeader(context, about),
                const SizedBox(height: 24),
                _buildDescription(context, about.description),
                const SizedBox(height: 32),

                _buildInfoTile(
                  icon: Icons.church,
                  title: 'Our Mission',
                  description: about.mission,
                ),
                const SizedBox(height: 16),

                _buildInfoTile(
                  icon: Icons.groups,
                  title: 'Our Community',
                  description: about.community,
                ),
                const SizedBox(height: 16),

                _buildInfoTile(
                  icon: Icons.favorite,
                  title: 'Our Values',
                  description: about.values,
                ),

                const SizedBox(height: 40),

                _buildFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AboutModel about) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.church, size: 64),
          const SizedBox(height: 12),
          Text(
            about.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            about.tagline,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: const [
          FooterContactsWidget(),
          SizedBox(height: 20),
          FooterSocialIconsWidget(),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
