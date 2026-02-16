import 'dart:ui';
import 'package:flutter/material.dart';

enum ShareFormat { square, story }
enum BackgroundType { color, image }

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
  ShareFormat format = ShareFormat.square;
  BackgroundType backgroundType = BackgroundType.color;

  Color backgroundColor = const Color(0xFFD6E3E7);
  Color fontColor = Colors.black;
  Color borderColor = Colors.transparent;

  double fontSize = 22;

  String? backgroundImage;

  final List<Color> palette = [
    const Color(0xFFF5E6E1),
    const Color(0xFFD6E3E7),
    const Color(0xFFDDE6DD),
    const Color(0xFFE8E0F2),
    const Color(0xFFF3E4DC),
    const Color(0xFF1C1C2E),
  ];

  @override
  Widget build(BuildContext context) {
    final height = format == ShareFormat.square ? 350.0 : 480.0;

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

          /// 🔹 Preview
          _buildPreview(height),

          const SizedBox(height: 20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// FORMAT
                  const Text("Format", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text("Background", style: TextStyle(fontWeight: FontWeight.bold)),
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

                  /// COLOR PALETTE
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
                            child: backgroundColor == color
                                ? const Icon(Icons.check, color: Colors.black)
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
              onPressed: () {
                // TODO: generate image and share
              },
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: backgroundType == BackgroundType.color
            ? backgroundColor
            : null,
        image: backgroundType == BackgroundType.image && backgroundImage != null
            ? DecorationImage(
                image: AssetImage(backgroundImage!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: backgroundType == BackgroundType.image
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backgroundImage != null)
                    Image.asset(backgroundImage!, fit: BoxFit.cover),

                  /// 🔥 FULL BLUR
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),

                  _buildTextContent(),
                ],
              ),
            )
          : _buildTextContent(),
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
                      blurRadius: 4,
                      color: borderColor,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
