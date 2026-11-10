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
  bool _zoomed = false;

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
          // While an image is zoomed, a horizontal drag has to pan that image
          // rather than flick to the next one — otherwise the pager steals
          // the gesture and zooming in makes the photo unexplorable.
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: (page) => setState(() {
            _page = page;
            // Each photo opens fitted, the way a gallery does; the next one
            // must not inherit the last one's magnification.
            _zoomed = false;
          }),
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            final heroTag = widget.heroTagBuilder?.call(imageUrl, index);
            return _ZoomableNetworkImage(
              key: ValueKey(imageUrl),
              imageUrl: imageUrl,
              heroTag: heroTag,
              isActive: index == _page,
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
              },
            );
          },
        ),
      );
}

class _ZoomableNetworkImage extends StatefulWidget {
  const _ZoomableNetworkImage({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.isActive = true,
    this.onZoomChanged,
  });

  final String imageUrl;
  final String? heroTag;

  /// False for the pager's off-screen neighbours, which reset themselves so
  /// a photo is never returned to still magnified.
  final bool isActive;

  final ValueChanged<bool>? onZoomChanged;

  @override
  State<_ZoomableNetworkImage> createState() => _ZoomableNetworkImageState();
}

class _ZoomableNetworkImageState extends State<_ZoomableNetworkImage> {
  final _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_reportZoom);
  }

  @override
  void didUpdateWidget(_ZoomableNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _transformationController.value = Matrix4.identity();
    }
  }

  /// Anything above 1 counts as zoomed. The epsilon keeps a pinch that lands
  /// a hair off identity from latching the pager shut.
  void _reportZoom() {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged?.call(zoomed);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_reportZoom);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Hero's own child is a bare image — no InteractiveViewer inside it
    // — so the incoming flight only ever animates plain image bounds. Pan
    // and pinch-zoom wrap it as a separate layer that only takes over once
    // the flight has settled.
    // Twice the screen's pixel width: enough that pinch-zoom still resolves
    // detail, while refusing to hold a full 12MP decode per open image. The
    // feed caps far harder (see _FeedImageGallery) because it keeps several
    // alive at once; here only one or two are.
    final zoomPixelWidth = (MediaQuery.of(context).size.width *
            MediaQuery.of(context).devicePixelRatio *
            2)
        .round();

    final image = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: zoomPixelWidth,
      placeholder: (_, __) => const Center(child: AppLoadingIndicator()),
      errorWidget: (_, __, ___) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 52,
        ),
      ),
    );
    final hero = widget.heroTag == null
        ? image
        : Hero(tag: widget.heroTag!, child: image);

    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 5,
        // Zero, not a margin. A margin is slack around the child, so the
        // photo could be dragged loose inside the black backdrop even at fit
        // scale — which no gallery does. At zero it cannot move until it is
        // bigger than the screen, and then only as far as its own edges.
        boundaryMargin: EdgeInsets.zero,
        child: Center(child: hero),
      ),
    );
  }

  void _toggleZoom() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const scale = 2.5;
    var dx = -position.dx * (scale - 1);
    var dy = -position.dy * (scale - 1);
    // Setting the matrix by hand bypasses InteractiveViewer's own clamping,
    // so a double-tap near an edge would jump past it and show empty space.
    // Clamp to the same bounds a drag would have been held to.
    final size = context.size;
    if (size != null) {
      dx = dx.clamp(-size.width * (scale - 1), 0.0);
      dy = dy.clamp(-size.height * (scale - 1), 0.0);
    }
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }
}
