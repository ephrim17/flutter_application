import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/widgets/footer_action_tile.dart';
import 'package:flutter_application/church_app/models/footer_support_models/social_icon_model.dart';
import 'package:flutter_application/church_app/providers/footer/footer_provider.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension _SocialIconModelPlatform on SocialIconModel {
  SocialPlatform get platform => SocialPlatform.fromStored(icon);
}

class FooterSocialIconsWidget extends ConsumerWidget {
  const FooterSocialIconsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconsAsync = ref.watch(footerSocialIconsProvider);

    return iconsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: AppLoadingIndicator(size: 64),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('${context.t('common.error_prefix')}: $e'),
      ),
      data: (social) => _buildSocialIcons(social, context),
    );
  }

  Widget _buildSocialIcons(
    List<SocialIconModel> social,
    BuildContext context,
  ) {
    return FooterActionWrap(
      children: [
        for (final item in social)
          FooterActionTile(
            icon: item.platform.icon,
            label: item.platform.label,
            // These were never tappable: the icons rendered, the model
            // carried a `url`, and nothing joined the two. A tile with no
            // usable link stays inert rather than pretending.
            onTap: _socialUri(item) == null
                ? null
                : () => launchExternalUri(
                      context,
                      _socialUri(item)!,
                      failureMessage: context.t('common.open_link_failed'),
                    ),
          ),
      ],
    );
  }

  /// Only absolute http(s) links are opened. A stored value that is a bare
  /// handle or a half-typed address would otherwise resolve to nothing, or
  /// to the app's own origin on the web.
  Uri? _socialUri(SocialIconModel item) {
    final raw = item.url.trim();
    if (raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return uri;
  }
}
