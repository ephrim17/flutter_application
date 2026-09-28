import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// How long a loaded image takes to fade in, everywhere in the app.
const Duration appImageFadeDuration = Duration(milliseconds: 260);

/// A network (or asset) image that fades in once it has loaded.
///
/// This used to sweep a shimmer highlight left-to-right across a grey box
/// while loading. In a feed that is mostly images — the Community tab, church
/// and global — several of those sweeping at once read as motion the eye
/// keeps chasing, drawing attention to the loading rather than the post. A
/// quiet placeholder plus a short fade says the same thing without the
/// animation. Named `ShimmerImage` still only because it is referenced from
/// several screens; it deliberately no longer shimmers.
class ShimmerImage extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final double borderRadius;
  final BoxFit fit;
  final Widget? errorWidget;

  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isRemote =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: isRemote
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: fit,
                width: double.infinity,
                fadeInDuration: appImageFadeDuration,
                fadeInCurve: Curves.easeOut,
                // Fading the placeholder out over the same beat would cross-
                // dissolve two greys; snapping it keeps the fade to one move.
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => const _ImagePlaceholder(),
                errorWidget: (context, url, error) =>
                    errorWidget ?? const _ImageFailed(),
              )
            : Image.asset(
                imageUrl,
                fit: fit,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    errorWidget ?? const _ImageFailed(),
              ),
      ),
    );
  }
}

/// The still, neutral box shown while an image loads.
class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}

class _ImageFailed extends StatelessWidget {
  const _ImageFailed();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 40,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
