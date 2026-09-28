import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_assets.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart'
    show appImageFadeDuration;

class ChurchLogoBuilder extends ConsumerWidget {
  const ChurchLogoBuilder({
    super.key,
    this.size = 38,
    this.fallbackAsset = AppAssets.churchTreeAppIcon,
    this.fit = BoxFit.cover,
  });

  final double size;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfigAsync = ref.watch(appConfigProvider);

    return appConfigAsync.when(
      loading: () => _logoPlaceholder(size),
      error: (_, __) => _fallbackLogo(),
      data: (config) => _buildLogo(config.churchLogo),
    );
  }

  Widget _buildLogo(String churchLogo) {
    final logo = churchLogo.trim();

    if (logo.isEmpty) {
      return _fallbackLogo();
    }

    final isUrl = logo.startsWith('http://') || logo.startsWith('https://');
    if (isUrl) {
      return Image.network(
        logo,
        height: size,
        width: size,
        fit: fit,
        // Fade the logo in rather than sweeping a shimmer behind it: a feed
        // shows one of these per post, and several sweeps at once is motion
        // the eye chases. `frameBuilder` runs once the frame is decoded,
        // `loadingBuilder` while bytes arrive.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: appImageFadeDuration,
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _logoPlaceholder(size);
        },
        errorBuilder: (_, __, ___) => _fallbackLogo(),
      );
    }

    return Image.asset(
      logo,
      height: size,
      width: size,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallbackLogo(),
    );
  }

  Widget _fallbackLogo() {
    return Image.asset(
      fallbackAsset,
      height: size,
      width: size,
      fit: fit,
    );
  }

  /// A still placeholder. Deliberately not a shimmer — see [ShimmerImage].
  Widget _logoPlaceholder(double size) {
    return Container(
      height: size,
      width: size,
      color: Colors.grey.shade200,
    );
  }
}
