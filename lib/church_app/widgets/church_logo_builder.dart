import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

class ChurchLogoBuilder extends ConsumerWidget {
  const ChurchLogoBuilder({
    super.key,
    this.size = 38,
    this.fallbackAsset = 'assets/images/church_logo.png',
    this.fit = BoxFit.cover,
  });

  final double size;
  final String fallbackAsset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfigAsync = ref.watch(appConfigProvider);

    return appConfigAsync.when(
      loading: () => _logoShimmer(size),
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _logoShimmer(size);
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

  Widget _logoShimmer(double size) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: size,
        width: size,
        color: Colors.white,
      ),
    );
  }
}
