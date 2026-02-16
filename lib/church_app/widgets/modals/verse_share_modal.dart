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

  double fontSize = 22;

  File? selectedImage;

  final List<Color> backgroundPalette = [
    const Color(0xFFF5E6E1),
    const Color(0xFFD6E3E7),
    const Color(0xFFDDE6DD),
    const Color(0xFFE8E0F2),
    const Color(0xFFF3E4DC),
    const Color(0xFF1C1C2E),
  ];

  final List<Color> fontPalette = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
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

          /// PREVIEW
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

                  /// BACKGROUND COLOR PICKER
                  if (backgroundType == BackgroundType.color)
                    Wrap(
                      spacing: 12,
                      children: backgroundPalette.map((color) {
                        final isSelected =
                            backgroundColor == color;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              backgroundColor = color;
                            });
                          },
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: color,
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() >
                                            0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  /// FONT SIZE
                  const Text("Font Size"),
                  Slider(
                    value: fontSize,
                    min: 14,
                    max: 50,
                    onChanged: (value) {
                      setState(() {
                        fontSize = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  /// FONT COLOR PICKER
                  const Text("Font Color",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: fontPalette.map((color) {
                      final isSelected =
                          fontColor == color;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            fontColor = color;
                          });
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: color,
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: color.computeLuminance() >
                                          0.5
                                      ? Colors.black
                                      : Colors.white,
                                )
                              : null,
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
                minimumSize:
                    const Size(double.infinity, 56),
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
        margin:
            const EdgeInsets.symmetric(horizontal: 20),
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

              if (backgroundType ==
                      BackgroundType.image &&
                  selectedImage != null)
                Image.file(
                  selectedImage!,
                  fit: BoxFit.cover,
                ),

              if (backgroundType ==
                      BackgroundType.image &&
                  selectedImage != null)
                BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color:
                        Colors.black.withOpacity(0.6),
                  ),
                ),

              if (backgroundType ==
                      BackgroundType.image &&
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

              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(24),
                  child: Text(
                    "${widget.text}\n\n- ${widget.reference}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight:
                          FontWeight.bold,
                      color: fontColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(
            source: ImageSource.gallery);

    if (file != null) {
      setState(() {
        selectedImage = File(file.path);
        backgroundType =
            BackgroundType.image;
      });
    }
  }

  Future<void> shareImage() async {
    try {
      await Future.delayed(
          const Duration(milliseconds: 50));

      final boundary =
          _previewKey.currentContext!
                  .findRenderObject()
              as RenderRepaintBoundary;

      final image =
          await boundary.toImage(
              pixelRatio: 3);

      final byteData =
          await image.toByteData(
              format:
                  ui.ImageByteFormat.png);

      final pngBytes =
          byteData!.buffer.asUint8List();

      final tempDir =
          await getTemporaryDirectory();

      final file = File(
          '${tempDir.path}/verse.png');

      await file.writeAsBytes(
          pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
      );
    } catch (e) {
      debugPrint(
          "Share error: $e");
    }
  }
}
