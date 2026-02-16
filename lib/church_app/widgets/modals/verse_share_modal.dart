import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

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
  bool isBold = true;

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
                    borderRadius: BorderRadius.circular(cornerRadius),
                    isSelected: [
                      format == ShareFormat.square,
                      format == ShareFormat.story,
                    ],
                    onPressed: (i) {
                      setState(() {
                        format =
                            i == 0 ? ShareFormat.square : ShareFormat.story;
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
                    borderRadius: BorderRadius.circular(cornerRadius),
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

                  /// BACKGROUND COLORS
                  if (backgroundType == BackgroundType.color)
                    Wrap(
                      spacing: 12,
                      children: backgroundPalette.map((color) {
                        final isSelected = backgroundColor == color;

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
                                    color: color.computeLuminance() > 0.5
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
                    max: 30,
                    onChanged: (value) {
                      setState(() {
                        fontSize = value;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  /// BOLD OPTION
                  const Text("Font Weight"),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    isSelected: [isBold, !isBold],
                    onPressed: (index) {
                      setState(() {
                        isBold = index == 0;
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Bold"),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("Normal"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// FONT COLOR
                  const Text("Font Color",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: fontPalette.map((color) {
                      final isSelected = fontColor == color;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            fontColor = color;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey.shade400,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: color,
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
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
              onPressed: downloadImage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: const Text("Download"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreview(double height) {
    return GestureDetector(
      onTap: backgroundType == BackgroundType.image ? pickImage : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              backgroundType == BackgroundType.color ? backgroundColor : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                Image.file(
                  selectedImage!,
                  fit: BoxFit.cover,
                ),

              /// 50% BLUR
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withAlpha(10),
                  ),
                ),

              if (backgroundType == BackgroundType.image &&
                  selectedImage == null)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 40),
                      SizedBox(height: 8),
                      Text("Tap to select image"),
                    ],
                  ),
                ),

              /// TEXT
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final maxHeight = constraints.maxHeight;

                      double adjustedSize = fontSize;

                      TextPainter painter = TextPainter(
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        maxLines: null,
                      );

                      while (adjustedSize > 12) {
                        painter.text = TextSpan(
                          text: "${widget.text}\n\n- ${widget.reference}",
                          style: TextStyle(
                            fontSize: adjustedSize,
                            fontWeight:
                                isBold ? FontWeight.bold : FontWeight.normal,
                            color: fontColor,
                          ),
                        );

                        painter.layout(maxWidth: maxWidth);

                        if (painter.height <= maxHeight - 30) {
                          break;
                        }

                        adjustedSize -= 1;
                      }

                      return Text(
                        "${widget.text}\n\n- ${widget.reference}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: adjustedSize,
                          fontWeight:
                              isBold ? FontWeight.bold : FontWeight.normal,
                          color: fontColor,
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// LOGO (BOTTOM RIGHT)
              Positioned(
                bottom: 12,
                right: 12,
                child: Opacity(
                  opacity: 0.85,
                  child: ClipOval(
                    child: Image.asset(
                      "assets/images/church_logo.png",
                      height: 38,
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
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() {
        selectedImage = File(file.path);
        backgroundType = BackgroundType.image;
      });
    }
  }

  Future<void> downloadImage() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(
        pngBytes,
        name: "daily_verse_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (!mounted) return;

      /// Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Saved to gallery"),
          duration: Duration(seconds: 2),
        ),
      );

      /// Small delay so snackbar is visible before closing
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.of(context).pop(); // dismiss modal
      }
    } catch (e) {
      debugPrint("Download error: $e");
    }
  }
}
