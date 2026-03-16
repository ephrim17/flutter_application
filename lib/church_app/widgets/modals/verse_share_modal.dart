import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/file_download.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/widgets/church_logo_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';

enum ShareFormat { square, story }

enum BackgroundType { color, image }

enum VerseFontStyleOption { bold, normal, italic }

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
  final TextEditingController _storyCaptionController = TextEditingController();

  ShareFormat format = ShareFormat.square;
  BackgroundType backgroundType = BackgroundType.color;

  Color backgroundColor = const Color(0xFFD6E3E7);
  Color fontColor = Colors.black;
  Color footerColor = Colors.black;

  double fontSize = 20;
  VerseFontStyleOption fontStyleOption = VerseFontStyleOption.bold;
  double blurIntensity = 10;
  int selectedFontStyleIndex = 0;

  PickedImageData? selectedImage;

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

  final List<_FontStyleOption> fontStyleOptions = const [
    _FontStyleOption(label: 'Default', fontFamily: null),
    _FontStyleOption(label: 'Serif', fontFamily: 'serif'),
    _FontStyleOption(label: 'Sans', fontFamily: 'sans-serif'),
    _FontStyleOption(label: 'Mono', fontFamily: 'monospace'),
    _FontStyleOption(label: 'Rounded', fontFamily: 'Roboto'),
  ];

  @override
  void dispose() {
    _storyCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.92;
    final height = format == ShareFormat.square
        ? sheetHeight * 0.34
        : sheetHeight * 0.46;

    return DefaultTabController(
      length: 3,
      child: Container(
        height: sheetHeight,
        decoration: carouselBoxDecoration(context),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: backgroundType == BackgroundType.color
                    ? backgroundColor
                    : (selectedImage == null ? Colors.grey.shade300 : null),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _previewKey,
              child: _buildPreview(height),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const TabBar(
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Layout'),
                    Tab(text: 'Style'),
                    Tab(text: 'Footer'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBarView(
                  children: [
                    _buildLayoutTab(),
                    _buildStyleTab(),
                    _buildFooterTab(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: downloadImage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text("Download"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(double height) {
    final storyCaption = _storyCaptionController.text.trim();
    final footerHeight = _reservedFooterHeight(storyCaption);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: backgroundType == BackgroundType.image ? pickImage : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: backgroundType == BackgroundType.color
              ? backgroundColor
              : Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                Image.memory(
                  selectedImage!.bytes,
                  fit: BoxFit.cover,
                ),
              if (backgroundType == BackgroundType.image &&
                  selectedImage != null)
                BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blurIntensity,
                    sigmaY: blurIntensity,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    footerHeight + 10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final maxHeight = constraints.maxHeight;
                      final fittedSize = _fitVerseTextSize(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      );

                      return SizedBox(
                        width: maxWidth,
                        height: maxHeight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: maxWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.text,
                                  textAlign: TextAlign.center,
                                  style: _textStyle(fittedSize),
                                ),
                                SizedBox(height: fittedSize * 0.9),
                                Text(
                                  "- ${widget.reference}",
                                  textAlign: TextAlign.center,
                                  style: _referenceTextStyle(fittedSize),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (backgroundType == BackgroundType.image &&
                  selectedImage == null)
                Positioned.fill(
                  child: Container(
                    color: Colors.grey.withValues(alpha: 0.65),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                        SizedBox(height: 12),
                        Text(
                          "Tap to select image",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                bottom: 14,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: format == ShareFormat.story ? 180 : 220,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _todayDateLabel(),
                        style: _footerTextStyle(
                          fontSize: format == ShareFormat.story ? 14 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (format == ShareFormat.story && storyCaption.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          storyCaption,
                          style: _footerTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Opacity(
                  opacity: 0.85,
                  child: ClipOval(
                    child: const ChurchLogoBuilder(size: 38),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Format',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            borderRadius: BorderRadius.circular(cornerRadius),
            isSelected: [
              format == ShareFormat.square,
              format == ShareFormat.story,
            ],
            onPressed: (i) {
              setState(() {
                format = i == 0 ? ShareFormat.square : ShareFormat.story;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Square'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Story'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Background',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            borderRadius: BorderRadius.circular(cornerRadius),
            isSelected: [
              backgroundType == BackgroundType.color,
              backgroundType == BackgroundType.image,
            ],
            onPressed: (i) {
              setState(() {
                backgroundType =
                    i == 0 ? BackgroundType.color : BackgroundType.image;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Color'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Image'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (backgroundType == BackgroundType.color)
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
          if (backgroundType == BackgroundType.image) ...[
            FilledButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                selectedImage == null ? 'Choose image' : 'Replace image',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Blur'),
            Slider(
              value: blurIntensity,
              min: 0,
              max: 24,
              divisions: 24,
              label: blurIntensity.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  blurIntensity = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Font Size'),
          Slider(
            value: fontSize,
            min: 12,
            max: 28,
            divisions: 16,
            label: fontSize.toStringAsFixed(0),
            onChanged: (value) {
              setState(() {
                fontSize = value;
              });
            },
          ),
          const SizedBox(height: 12),
          const Text('Font Style'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(fontStyleOptions.length, (index) {
              final option = fontStyleOptions[index];
              final selected = index == selectedFontStyleIndex;
              return ChoiceChip(
                label: Text(option.label),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    selectedFontStyleIndex = index;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text('Font Weight'),
          const SizedBox(height: 8),
          ToggleButtons(
            borderRadius: BorderRadius.circular(cornerRadius),
            isSelected: [
              fontStyleOption == VerseFontStyleOption.bold,
              fontStyleOption == VerseFontStyleOption.normal,
              fontStyleOption == VerseFontStyleOption.italic,
            ],
            onPressed: (index) {
              setState(() {
                fontStyleOption = VerseFontStyleOption.values[index];
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Bold'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Normal'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Italic'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Font Color',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
                      color: isSelected ? Colors.black : Colors.grey.shade400,
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
        ],
      ),
    );
  }

  Widget _buildFooterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date: ${_todayDateLabel()}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('The current date is always shown on the card.'),
          const SizedBox(height: 20),
          const Text(
            'Footer Color',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fontPalette.map((color) {
              final isSelected = footerColor == color;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    footerColor = color;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade400,
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
          const SizedBox(height: 20),
          if (format == ShareFormat.story)
            TextField(
              controller: _storyCaptionController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Bottom-left text (optional)',
                helperText: 'Only shown in story mode',
              ),
              onChanged: (_) {
                setState(() {});
              },
            )
          else
            const Text(
              'Switch to story mode if you want to add an optional footer note.',
            ),
        ],
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final imageData = await PickedImageData.fromXFile(file);
      if (imageData == null) return;
      setState(() {
        selectedImage = imageData;
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
      final fileName = "daily_verse_${DateTime.now().millisecondsSinceEpoch}.png";

      if (kIsWeb) {
        await downloadBytes(
          bytes: pngBytes,
          fileName: fileName,
          mimeType: 'image/png',
        );
      } else {
        await Gal.putImageBytes(
          pngBytes,
          name: "daily_verse_${DateTime.now().millisecondsSinceEpoch}",
        );
      }

      if (!mounted) return;

      /// Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb ? "Image downloaded" : "Saved to gallery",
          ),
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

  TextStyle _textStyle(double size) {
    final selectedFont = fontStyleOptions[selectedFontStyleIndex];
    return TextStyle(
      fontSize: size,
      fontWeight: _resolvedFontWeight(),
      color: fontColor,
      fontFamily: selectedFont.fontFamily,
      fontStyle: _resolvedFontStyle(),
    );
  }

  TextStyle _referenceTextStyle(double size) {
    final selectedFont = fontStyleOptions[selectedFontStyleIndex];
    return TextStyle(
      fontSize: size * 0.72,
      fontWeight: FontWeight.w700,
      color: fontColor,
      fontFamily: selectedFont.fontFamily,
      fontStyle: _resolvedFontStyle(),
      height: 1.2,
    );
  }

  FontWeight _resolvedFontWeight() {
    switch (fontStyleOption) {
      case VerseFontStyleOption.bold:
        return FontWeight.bold;
      case VerseFontStyleOption.normal:
      case VerseFontStyleOption.italic:
        return FontWeight.normal;
    }
  }

  FontStyle _resolvedFontStyle() {
    return fontStyleOption == VerseFontStyleOption.italic
        ? FontStyle.italic
        : FontStyle.normal;
  }

  double _fitVerseTextSize({
    required double maxWidth,
    required double maxHeight,
  }) {
    double adjustedSize = fontSize;
    const safetyPadding = 10.0;

    while (adjustedSize > 10) {
      final versePainter = TextPainter(
        text: TextSpan(
          text: widget.text,
          style: _textStyle(adjustedSize),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidth);

      final referencePainter = TextPainter(
        text: TextSpan(
          text: "- ${widget.reference}",
          style: _referenceTextStyle(adjustedSize),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: maxWidth);

      final spacing = adjustedSize * 0.9;
      final totalHeight =
          versePainter.height + spacing + referencePainter.height;

      if (totalHeight <= maxHeight - safetyPadding) {
        break;
      }

      adjustedSize -= 1;
    }

    return adjustedSize;
  }

  double _reservedFooterHeight(String storyCaption) {
    if (format != ShareFormat.story) {
      return 34;
    }

    if (storyCaption.isEmpty) {
      return 40;
    }

    return 68;
  }

  TextStyle _footerTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return TextStyle(
      color: footerColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.2,
    );
  }

  String _todayDateLabel() {
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }
}

class _FontStyleOption {
  final String label;
  final String? fontFamily;

  const _FontStyleOption({
    required this.label,
    required this.fontFamily,
  });
}
