import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/providers/footer/footer_provider.dart';
import 'package:flutter_application/church_app/widgets/copy_rights_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class FooterSocialIconsWidget extends ConsumerWidget {
  const FooterSocialIconsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconsAsync = ref.watch(footerSocialIconsProvider);

    return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Text(
          //   "Follow us on",
          //   style: Theme.of(context).textTheme.titleMedium,
          // ),
          const SizedBox(height: 16),

          iconsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Footer error: $e'),
            ),
            data: (social) => _buildSocialIconsRow(social, context),
          ),
          const SizedBox(height: 16),
          const CopyrightWidget(),
        ],
      );
  }

  Widget _buildSocialIconsRow(List<SocialIconModel> social, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: social
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10), // 20 total gap
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _socialIconType(item.icon),
                  const SizedBox(height: 8),
                  Text(
                    item.icon,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

Icon _socialIconType(String type) {
  switch (type) {
    case 'Facebook':
      return const Icon(Icons.facebook);
    case 'Youtube':
      return const Icon(Icons.play_arrow);
    default:
      return const Icon(Icons.link);
  }
}
