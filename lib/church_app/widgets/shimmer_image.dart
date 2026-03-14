import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

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
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) =>
                    errorWidget ??
                    Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
              )
            : Image.asset(
                imageUrl,
                fit: fit,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    errorWidget ??
                    Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
              ),
      ),
    );
  }
}
