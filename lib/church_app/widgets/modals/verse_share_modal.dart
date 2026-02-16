import 'dart:ui';
import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ShareFormat { square, story }
enum BackgroundType { color, image }

Future<void> showVerseShareModal(
  BuildContext context, {
  required String text,
  required String reference,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => VerseShareModal(
      text: text,
      reference: reference,
    ),
  );
}

class VerseShareModal extends StatefulWidget {
  final String text;
  final String reference;

  const VerseShareModal({
    super.key,
    required this.text,
    required this.reference,
  });

  @override
  State<VerseShareModal> createState() => _VerseShareModalState();
}

class _VerseShareModalState extends State<VerseShareModal> {
  final GlobalKey _previewKey = GlobalKey();

  ShareFormat format = ShareFormat.square;
  BackgroundType backgroundType = BackgroundType.color;

  Color backgroundColor = const Color(0xFFD6E3E7);
  Color fontColor = Colors.black;
  Color borderColor = Colors.transparent;

  double fontSize = 22;

  File? selectedImage;

  final List<Color> palette = [
    const Color(0xFFF5E6E1),
    const Color(0xFFD6E3E7),
    const Color(0xFFDDE6DD),
    const Color(0xFFE8E0F2),
    const Color(0xFFF3E4DC),
    const Color(0xFF1C1C2E),
    Colors.black,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final height = format == ShareFormat.square ? 280.0 : 420.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),

          /// 🔥 PREVIEW
          RepaintBoundary(
            key: _previewKey,
            child: _buildPreview(height),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// FORMAT
                  const Text("Format",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [
                      format == ShareFormat.square,
                      format == ShareFormat.story,
                    ],
                    onPressed: (i) {
                      setState(() {
                        format = i == 0
                            ? ShareFormat.square
                            : ShareFormat.story;
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Square"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Story"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// BACKGROUND TYPE
                  const Text("Background",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [
                      backgroundType == BackgroundType.color,
                      backgroundType == BackgroundType.image,
                    ],
                    onPressed: (i) {
                      setState(() {
                        backgroundType = i == 0
                            ? BackgroundType.color
                            : BackgroundType.image;
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Color"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Image"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// COLOR PICKER
                  if (backgroundType == BackgroundType.color)
                    Wrap(
                      spacing: 10,
                      children: palette.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              backgroundColor = color;
                            });
                          },
                          child: CircleAvatar(
                            backgroundColor: color,
                            radius: 20,
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  /// FONT SIZE
                  const Text("Font Size"),
                  Slider(
                    value: fontSize,
                    min: 16,
                    max: 40,
                    onChanged: (v) {
                      setState(() => fontSize = v);
                    },
                  ),

                  const SizedBox(height: 10),

                  /// FONT COLOR
                  const Text("Font Color"),
                  Wrap(
                    spacing: 10,
                    children: palette.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            fontColor = color;
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 18,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  /// BORDER COLOR
                  const Text("Text Border"),
                  Wrap(
                    spacing: 10,
                    children: palette.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            borderColor = color;
                          });
                        },
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 18,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: shareImage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text("Share"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreview(double height) {
    return GestureDetector(
      onTap: backgroundType == BackgroundType.image
          ? pickImage
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: backgroundType == BackgroundType.color
              ? backgroundColor
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [

              /// IMAGE
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                Image.file(
                  selectedImage!,
                  fit: BoxFit.cover,
                ),

              /// 🔥 90% BLUR
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 35, sigmaY: 35),
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),

              /// TAP HINT
              if (backgroundType == BackgroundType.image &&
                  selectedImage == null)
                const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 40),
                      SizedBox(height: 8),
                      Text("Tap to select image"),
                    ],
                  ),
                ),

              _buildTextContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          "${widget.text}\n\n- ${widget.reference}",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            color: fontColor,
            fontWeight: FontWeight.bold,
            shadows: borderColor != Colors.transparent
                ? [
                    Shadow(
                      blurRadius: 6,
                      color: borderColor,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() {
        selectedImage = File(file.path);
        backgroundType = BackgroundType.image;
      });
    }
  }

  Future<void> shareImage() async {
    try {
      final boundary =
          _previewKey.currentContext!
                  .findRenderObject()
              as RenderRepaintBoundary;

      final image =
          await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);

      final pngBytes =
          byteData!.buffer.asUint8List();

      final tempDir =
          await getTemporaryDirectory();

      final file = await File(
        '${tempDir.path}/verse.png',
      ).create();

      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
      );
    } catch (e) {
      debugPrint("Share error: $e");
    }
  }
}
