import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';

typedef AppImageHeroTagBuilder = String Function(String imageUrl, int index);

Future<void> showAppImageGallery(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? title,
  AppImageHeroTagBuilder? heroTagBuilder,
}) {
  if (imageUrls.isEmpty) return Future.value();
  final safeIndex = initialIndex.clamp(0, imageUrls.length - 1);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AppImageGalleryViewer(
        imageUrls: imageUrls,
        initialIndex: safeIndex,
        title: title,
        heroTagBuilder: heroTagBuilder,
      ),
    ),
  );
}

class AppImageGalleryViewer extends StatefulWidget {
  const AppImageGalleryViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title,
    this.heroTagBuilder,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final String? title;
  final AppImageHeroTagBuilder? heroTagBuilder;

  @override
  State<AppImageGalleryViewer> createState() => _AppImageGalleryViewerState();
}

class _AppImageGalleryViewerState extends State<AppImageGalleryViewer> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            widget.imageUrls.length > 1
                ? context.t(
                    'common.image_position',
                    parameters: {
                      'current': _page + 1,
                      'total': widget.imageUrls.length,
                    },
                  )
                : widget.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (page) => setState(() => _page = page),
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            final heroTag = widget.heroTagBuilder?.call(imageUrl, index);
            final image = _ZoomableNetworkImage(imageUrl: imageUrl);
            return Center(
              child: heroTag == null ? image : Hero(tag: heroTag, child: image),
            );
          },
        ),
      );
}

class _ZoomableNetworkImage extends StatefulWidget {
  const _ZoomableNetworkImage({required this.imageUrl});

  final String imageUrl;

  @override
  State<_ZoomableNetworkImage> createState() => _ZoomableNetworkImageState();
}

class _ZoomableNetworkImageState extends State<_ZoomableNetworkImage> {
  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(36),
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: AppLoadingIndicator(),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 52,
              ),
            ),
          ),
        ),
      );

  void _toggleZoom() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, scale, 1);
  }
}
