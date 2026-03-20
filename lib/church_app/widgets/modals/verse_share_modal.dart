import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/file_download.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const double _downloadScaleMultiplier = 3.6;

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
    _FontStyleOption(
        labelKey: 'verse_share.default_font',
        fallback: 'Default',
        fontFamily: null),
    _FontStyleOption(
        labelKey: 'verse_share.serif_font',
        fallback: 'Serif',
        fontFamily: 'serif'),
    _FontStyleOption(
        labelKey: 'verse_share.sans_font',
        fallback: 'Sans',
        fontFamily: 'sans-serif'),
    _FontStyleOption(
        labelKey: 'verse_share.mono_font',
        fallback: 'Mono',
        fontFamily: 'monospace'),
    _FontStyleOption(
        labelKey: 'verse_share.rounded_font',
        fallback: 'Rounded',
        fontFamily: 'Roboto'),
  ];

  @override
  void dispose() {
    _storyCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.92;
    final height =
        format == ShareFormat.square ? sheetHeight * 0.34 : sheetHeight * 0.46;

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
                child: TabBar(
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      text: context.t('verse_share.layout', fallback: 'Layout'),
                    ),
                    Tab(
                      text: context.t('verse_share.style', fallback: 'Style'),
                    ),
                    Tab(
                      text: context.t('verse_share.footer', fallback: 'Footer'),
                    ),
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
                  child: Text(
                    context.t('common.download', fallback: 'Download'),
                  ),
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
                      if (format == ShareFormat.story &&
                          storyCaption.isNotEmpty) ...[
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
                  child: const _VerseShareBranding(),
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
          Text(
            context.t('verse_share.format', fallback: 'Format'),
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
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.square', fallback: 'Square'),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.story', fallback: 'Story'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            context.t('verse_share.background', fallback: 'Background'),
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
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.color', fallback: 'Color'),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.image', fallback: 'Image'),
                ),
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
                selectedImage == null
                    ? context.t(
                        'verse_share.choose_image',
                        fallback: 'Choose image',
                      )
                    : context.t(
                        'verse_share.replace_image',
                        fallback: 'Replace image',
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.t('verse_share.blur', fallback: 'Blur')),
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
          Text(context.t('verse_share.font_size', fallback: 'Font Size')),
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
          Text(context.t('verse_share.font_style', fallback: 'Font Style')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(fontStyleOptions.length, (index) {
              final option = fontStyleOptions[index];
              final selected = index == selectedFontStyleIndex;
              return ChoiceChip(
                label: Text(
                  context.t(option.labelKey, fallback: option.fallback),
                ),
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
          Text(context.t('verse_share.font_weight', fallback: 'Font Weight')),
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
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(context.t('verse_share.bold', fallback: 'Bold')),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.normal', fallback: 'Normal'),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.t('verse_share.italic', fallback: 'Italic'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t('verse_share.font_color', fallback: 'Font Color'),
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

      final image = await boundary.toImage(
        pixelRatio: _downloadScaleMultiplier,
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final pngBytes = byteData!.buffer.asUint8List();
      final fileName =
          "daily_verse_${DateTime.now().millisecondsSinceEpoch}.png";

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

class _VerseShareBranding extends ConsumerWidget {
  const _VerseShareBranding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    final churchLogo = configAsync.maybeWhen(
      data: (config) => config.churchLogo.trim(),
      orElse: () => '',
    );
    final appTitle = ref.t('church_tab.app_title', fallback: 'Church');

    if (churchLogo.isNotEmpty) {
      final uri = Uri.tryParse(churchLogo);
      final isNetwork =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

      return ClipOval(
        child: isNetwork
            ? Image.network(
                churchLogo,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _BrandText(appTitle: appTitle),
              )
            : Image.asset(
                churchLogo,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _BrandText(appTitle: appTitle),
              ),
      );
    }

    return _BrandText(appTitle: appTitle);
  }
}

class _BrandText extends StatelessWidget {
  const _BrandText({
    required this.appTitle,
  });

  final String appTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        appTitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FontStyleOption {
  final String labelKey;
  final String fallback;
  final String? fontFamily;

  const _FontStyleOption({
    required this.labelKey,
    required this.fallback,
    required this.fontFamily,
  });
}
