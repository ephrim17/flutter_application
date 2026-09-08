import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// Opens the gallery, converts the selection to bytes, then shows the crop
/// preview — the full pick-to-confirm pipeline shared by every entry point
/// that lets a user attach photos to a feed post.
/// Returns an empty list (never null) if the user backs out anywhere.
///
/// `wechat_assets_picker` (the rich in-app gallery grid) is backed by
/// `photo_manager`, which has no web implementation, so web uses the
/// browser's native file picker via `image_picker` instead.
Future<List<PickedImageData>> pickAndPreviewFeedImages(
  BuildContext context, {
  int maxAssets = 10,
}) async {
  final List<PickedImageData> pickedImages;
  if (kIsWeb) {
    pickedImages = await _pickImagesWeb(maxAssets: maxAssets);
  } else {
    if (!context.mounted) return const [];
    pickedImages = await _pickImagesNative(context, maxAssets: maxAssets);
  }
  if (pickedImages.isEmpty || !context.mounted) return const [];

  final confirmed = await showFeedImageCropPreview(context, images: pickedImages);
  return confirmed ?? const [];
}

Future<List<PickedImageData>> _pickImagesNative(
  BuildContext context, {
  required int maxAssets,
}) async {
  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: AssetPickerConfig(
      maxAssets: maxAssets,
      requestType: RequestType.image,
    ),
  );
  if (assets == null || assets.isEmpty) return const [];

  final pickedImages = <PickedImageData>[];
  for (final asset in assets) {
    final bytes = await asset.originBytes;
    if (bytes == null) continue;
    pickedImages.add(
      PickedImageData(bytes: bytes, name: await asset.titleAsync),
    );
  }
  return pickedImages;
}

Future<List<PickedImageData>> _pickImagesWeb({required int maxAssets}) async {
  final files = await ImagePicker().pickMultiImage(limit: maxAssets);
  final pickedImages = <PickedImageData>[];
  for (final file in files) {
    final picked = await PickedImageData.fromXFile(file);
    if (picked != null) pickedImages.add(picked);
  }
  return pickedImages;
}

/// Opens the device camera, converts the capture to bytes, then shows the
/// same crop preview used by the gallery pick flow.
/// Returns an empty list (never null) if the user backs out anywhere.
Future<List<PickedImageData>> captureAndPreviewFeedImage(
  BuildContext context,
) async {
  final file =
      await ImagePicker().pickImage(source: ImageSource.camera);
  final picked = await PickedImageData.fromXFile(file);
  if (picked == null || !context.mounted) return const [];

  final confirmed =
      await showFeedImageCropPreview(context, images: [picked]);
  return confirmed ?? const [];
}

/// Shows how each picked image will look once cropped to fill the
/// Community tab's full-bleed frame, with a toggle to check the untouched
/// original before confirming. Returns the (unchanged) image list if the
/// user confirms, or null if they back out.
Future<List<PickedImageData>?> showFeedImageCropPreview(
  BuildContext context, {
  required List<PickedImageData> images,
}) {
  return Navigator.of(context).push<List<PickedImageData>?>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FeedImageCropPreviewScreen(images: images),
    ),
  );
}

class _FeedImageCropPreviewScreen extends StatefulWidget {
  const _FeedImageCropPreviewScreen({required this.images});

  final List<PickedImageData> images;

  @override
  State<_FeedImageCropPreviewScreen> createState() =>
      _FeedImageCropPreviewScreenState();
}

class _FeedImageCropPreviewScreenState
    extends State<_FeedImageCropPreviewScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _showFullImage = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) => setState(() {
                      _page = index;
                      _showFullImage = false;
                    }),
                    itemBuilder: (context, index) {
                      return AspectRatio(
                        aspectRatio: screenSize.width / screenSize.height,
                        child: ColoredBox(
                          color: Colors.black,
                          child: Image.memory(
                            widget.images[index].bytes,
                            fit: _showFullImage ? BoxFit.contain : BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (widget.images.length > 1)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            width: index == _page ? 16 : 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: index == _page ? 0.95 : 0.45,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showFullImage = !_showFullImage),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showFullImage
                                    ? Icons.crop_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showFullImage
                                    ? context.t('ui.feed.show_cropped_preview')
                                    : context.t('ui.feed.view_full_image'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(widget.images),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(context.t('ui.feed.use_photos')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
