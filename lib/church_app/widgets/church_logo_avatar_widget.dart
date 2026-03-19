import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ChurchLogoAvatar extends StatelessWidget {
  const ChurchLogoAvatar({
    super.key,
    required this.logo,
    this.size = 48,
  });

  final String logo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = logo.trim();

    if (trimmed.isEmpty) {
      return _fallback(context);
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return _networkLogo(context, trimmed);
    }

    return _assetLogo(context, trimmed);
  }

  Widget _networkLogo(BuildContext context, String url) {
    return _logoShell(
      context,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _loading(context),
          errorWidget: (_, __, ___) => _fallback(context),
        ),
      ),
    );
  }

  Widget _assetLogo(BuildContext context, String assetPath) {
    return _logoShell(
      context,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        ),
      ),
    );
  }

  Widget _loading(BuildContext context) {
    return _logoShell(
      context,
      child: const Center(
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return _logoShell(
      context,
      child: Icon(
        Icons.church_outlined,
        size: size * 0.45,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _logoShell(BuildContext context, {required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).cardTheme.color,
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
