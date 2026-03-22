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

enum HighlightPreset { emphasis, outline }

enum HighlightMatchMode { all, firstOnly, next }

enum HighlightTarget { verse, reference }

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
  final Map<String, TextEditingController> _highlightControllers = {};

  ShareFormat format = ShareFormat.square;
  BackgroundType backgroundType = BackgroundType.color;

  Color backgroundColor = const Color(0xFFD6E3E7);
  Color fontColor = Colors.black;
  Color footerColor = Colors.black;

  double fontSize = 20;
  VerseFontStyleOption fontStyleOption = VerseFontStyleOption.bold;
  double blurIntensity = 10;
  int selectedFontStyleIndex = 0;
  final List<_HighlightRule> _highlightRules = [];

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
    Colors.transparent,
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  final List<Color> fillPalette = [
    Colors.transparent,
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
    for (final controller in _highlightControllers.values) {
      controller.dispose();
    }
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
                                Text.rich(
                                  TextSpan(
                                    children: _buildVerseInlineSpans(
                                      fittedSize,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: fittedSize * 0.9),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '- ',
                                        style: _referenceTextStyle(fittedSize),
                                      ),
                                      ..._buildReferenceInlineSpans(fittedSize),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
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
          _buildSectionCard(
            title: context.t(
              'verse_share.base_style',
              fallback: 'Base Style',
            ),
            description: context.t(
              'verse_share.base_style_desc',
              fallback:
                  'This style applies to the full verse unless a highlight rule overrides part of it.',
            ),
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
                Text(
                  context.t('verse_share.font_style', fallback: 'Font Family'),
                ),
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
                Text(
                  context.t('verse_share.font_weight', fallback: 'Font Weight'),
                ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        context.t('verse_share.bold', fallback: 'Bold'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        context.t('verse_share.normal', fallback: 'Normal'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        context.t('verse_share.italic', fallback: 'Italic'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildColorPaletteSection(
                  title: context.t(
                    'verse_share.font_color',
                    fallback: 'Font Color',
                  ),
                  selectedColor: fontColor,
                  colors: fontPalette,
                  onSelected: (color) {
                    setState(() {
                      fontColor = color;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: context.t(
              'verse_share.highlights',
              fallback: 'Highlights',
            ),
            description: context.t(
              'verse_share.highlights_desc',
              fallback:
                  'Add multiple words or phrases and give each one its own look.',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_highlightRules.isEmpty)
                  Text(
                    context.t(
                      'verse_share.highlights_empty',
                      fallback:
                          'No highlight rules yet. Add one to style a specific word or phrase.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Column(
                    children: [
                      for (final rule in _highlightRules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildHighlightRuleCard(rule),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addHighlightRule,
                  icon: const Icon(Icons.add),
                  label: Text(
                    context.t(
                      'verse_share.add_highlight',
                      fallback: 'Add Highlight',
                    ),
                  ),
                ),
              ],
            ),
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
          Text(
            context.t(
              'verse_share.footer_date_note',
              fallback: 'The current date is always shown on the card.',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.t(
              'verse_share.footer_color',
              fallback: 'Footer Color',
            ),
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
              decoration: InputDecoration(
                labelText: context.t(
                  'verse_share.bottom_left_text_optional',
                  fallback: 'Bottom-left text (optional)',
                ),
                helperText: context.t(
                  'verse_share.story_footer_helper',
                  fallback: 'Only shown in story mode',
                ),
              ),
              onChanged: (_) {
                setState(() {});
              },
            )
          else
            Text(
              context.t(
                'verse_share.story_footer_note',
                fallback:
                    'Switch to story mode if you want to add an optional footer note.',
              ),
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

  List<InlineSpan> _buildVerseInlineSpans(double size) {
    final matches = _resolvedHighlightMatches(
      source: widget.text,
      target: HighlightTarget.verse,
    );
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: widget.text,
          style: _textStyle(size),
        ),
      ];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.text.substring(cursor, match.start),
            style: _textStyle(size),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: widget.text.substring(match.start, match.end),
          style: _highlightTextStyle(
            rule: match.rule,
            size: size,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(cursor),
          style: _textStyle(size),
        ),
      );
    }

    return spans;
  }

  List<InlineSpan> _buildReferenceInlineSpans(double size) {
    final matches = _resolvedHighlightMatches(
      source: widget.reference,
      target: HighlightTarget.reference,
    );
    if (matches.isEmpty) {
      return [
        TextSpan(
          text: widget.reference,
          style: _referenceTextStyle(size),
        ),
      ];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.reference.substring(cursor, match.start),
            style: _referenceTextStyle(size),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: widget.reference.substring(match.start, match.end),
          style: _highlightTextStyle(
            rule: match.rule,
            size: size * 0.72,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < widget.reference.length) {
      spans.add(
        TextSpan(
          text: widget.reference.substring(cursor),
          style: _referenceTextStyle(size),
        ),
      );
    }

    return spans;
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

  TextStyle _highlightTextStyle({
    required _HighlightRule rule,
    required double size,
  }) {
    final selectedFont = fontStyleOptions[rule.fontStyleIndex];
    final resolvedSize = size * rule.sizeScale;
    final presetStyle = _presetVisualStyle(rule.preset);

    return TextStyle(
      fontSize: resolvedSize,
      color: rule.textColor,
      fontFamily: selectedFont.fontFamily,
      fontStyle: rule.fontStyleOption == VerseFontStyleOption.italic
          ? FontStyle.italic
          : FontStyle.normal,
      fontWeight: rule.fontStyleOption == VerseFontStyleOption.bold
          ? FontWeight.w800
          : FontWeight.w500,
      letterSpacing: presetStyle.letterSpacing,
      backgroundColor:
          rule.fillColor.withValues(alpha: presetStyle.fillOpacity),
      shadows: _buildHighlightShadows(
        borderColor: rule.borderColor,
        preset: rule.preset,
      ),
      decoration: TextDecoration.none,
      decorationColor: rule.borderColor,
      decorationThickness: null,
      height: 1.28,
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
          children: _buildVerseInlineSpans(adjustedSize),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: maxWidth);

      final referencePainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '- ',
              style: _referenceTextStyle(adjustedSize),
            ),
            ..._buildReferenceInlineSpans(adjustedSize),
          ],
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

  Widget _buildSectionCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildColorPaletteSection({
    required String title,
    required Color selectedColor,
    required List<Color> colors,
    required ValueChanged<Color> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () => onSelected(color),
              child: _buildColorDot(
                color: color,
                isSelected: selectedColor == color,
                isClear: color == Colors.transparent,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _addHighlightRule() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _highlightRules.add(
        _HighlightRule(
          id: id,
          phrase: '',
          target: HighlightTarget.verse,
          preset: HighlightPreset.emphasis,
          fontStyleOption: VerseFontStyleOption.bold,
          textColor: Colors.white,
          fillColor: Theme.of(context).colorScheme.primary,
          borderColor: Theme.of(context).colorScheme.primaryContainer,
          fontStyleIndex: selectedFontStyleIndex,
          sizeScale: 1.0,
          matchMode: HighlightMatchMode.all,
          occurrenceIndex: 0,
        ),
      );
      _highlightControllers[id] = TextEditingController();
    });
  }

  void _removeHighlightRule(_HighlightRule rule) {
    _highlightControllers.remove(rule.id)?.dispose();
    setState(() {
      _highlightRules.removeWhere((item) => item.id == rule.id);
    });
  }

  Widget _buildHighlightRuleCard(_HighlightRule rule) {
    final controller = _highlightControllers.putIfAbsent(
      rule.id,
      () => TextEditingController(text: rule.phrase),
    );
    final title = rule.phrase.trim().isEmpty
        ? context.t(
            'verse_share.highlight_rule_title',
            fallback: 'New Highlight',
          )
        : rule.phrase.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: context.t(
                  'common.delete',
                  fallback: 'Delete',
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeHighlightRule(rule),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.t(
                'verse_share.phrase',
                fallback: 'Word or Phrase',
              ),
              hintText: context.t(
                'verse_share.phrase_hint',
                fallback: 'Type the exact word or phrase to style',
              ),
            ),
            onChanged: (value) {
              _updateRule(rule, (current) => current.copyWith(phrase: value));
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.t('verse_share.preset', fallback: 'Preset'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HighlightTarget.values.map((target) {
              final selected = rule.target == target;
              return ChoiceChip(
                label: Text(
                  target == HighlightTarget.verse
                      ? context.t('verse_share.target_verse', fallback: 'Verse')
                      : context.t(
                          'verse_share.target_reference',
                          fallback: 'Reference',
                        ),
                ),
                selected: selected,
                onSelected: (_) {
                  _updateRule(
                    rule,
                    (current) => current.copyWith(target: target),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('verse_share.target', fallback: 'Target'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HighlightPreset.values.map((preset) {
              final selected = rule.preset == preset;
              return ChoiceChip(
                label: Text(_presetLabel(preset)),
                selected: selected,
                onSelected: (_) {
                  _updateRule(
                    rule,
                    (current) => current.copyWith(preset: preset),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            context.t('verse_share.match_mode', fallback: 'Match Mode'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HighlightMatchMode.values.map((mode) {
              final selected = rule.matchMode == mode;
              return ChoiceChip(
                label: Text(
                  mode == HighlightMatchMode.all
                      ? context.t('verse_share.all_matches', fallback: 'All')
                      : mode == HighlightMatchMode.firstOnly
                          ? context.t(
                              'verse_share.first_match',
                              fallback: 'First Only',
                            )
                          : context.t(
                              'verse_share.next_match',
                              fallback: 'Next',
                            ),
                ),
                selected: selected,
                onSelected: (_) {
                  _updateRule(
                    rule,
                    (current) {
                      if (mode == HighlightMatchMode.next &&
                          current.matchMode == HighlightMatchMode.next) {
                        return current.copyWith(
                          occurrenceIndex: current.occurrenceIndex + 1,
                        );
                      }

                      return current.copyWith(
                        matchMode: mode,
                        occurrenceIndex: 0,
                      );
                    },
                  );
                },
              );
            }).toList(),
          ),
          if (rule.matchMode == HighlightMatchMode.next) ...[
            const SizedBox(height: 8),
            Text(
              context.t(
                'verse_share.next_match_hint',
                fallback:
                    'Tap Next again to move the highlight to the next occurrence.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: rule.fontStyleIndex,
            decoration: InputDecoration(
              labelText: context.t(
                'verse_share.highlight_font',
                fallback: 'Highlight Font',
              ),
            ),
            items: List.generate(fontStyleOptions.length, (index) {
              final option = fontStyleOptions[index];
              return DropdownMenuItem(
                value: index,
                child: Text(
                  context.t(option.labelKey, fallback: option.fallback),
                ),
              );
            }),
            onChanged: (value) {
              if (value == null) return;
              _updateRule(
                rule,
                (current) => current.copyWith(fontStyleIndex: value),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            context.t('verse_share.highlight_weight', fallback: 'Font Style'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ToggleButtons(
            borderRadius: BorderRadius.circular(cornerRadius),
            isSelected: [
              rule.fontStyleOption == VerseFontStyleOption.bold,
              rule.fontStyleOption == VerseFontStyleOption.normal,
              rule.fontStyleOption == VerseFontStyleOption.italic,
            ],
            onPressed: (index) {
              _updateRule(
                rule,
                (current) => current.copyWith(
                  fontStyleOption: VerseFontStyleOption.values[index],
                ),
              );
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.t('verse_share.bold', fallback: 'Bold')),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.t('verse_share.normal', fallback: 'Normal'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.t('verse_share.italic', fallback: 'Italic'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${context.t('verse_share.scale', fallback: 'Scale')}: '
            '${rule.sizeScale.toStringAsFixed(2)}x',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: rule.sizeScale,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            label: rule.sizeScale.toStringAsFixed(2),
            onChanged: (value) {
              _updateRule(
                rule,
                (current) => current.copyWith(sizeScale: value),
              );
            },
          ),
          _buildColorPaletteSection(
            title: context.t(
              'verse_share.highlight_text_color',
              fallback: 'Text Color',
            ),
            selectedColor: rule.textColor,
            colors: fillPalette,
            onSelected: (color) {
              _updateRule(
                rule,
                (current) => current.copyWith(textColor: color),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildColorPaletteSection(
            title: context.t(
              'verse_share.highlight_fill_color',
              fallback: 'Fill Color',
            ),
            selectedColor: rule.fillColor,
            colors: fillPalette,
            onSelected: (color) {
              _updateRule(
                rule,
                (current) => current.copyWith(fillColor: color),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildColorPaletteSection(
            title: context.t(
              'verse_share.highlight_border_color',
              fallback: 'Border Color',
            ),
            selectedColor: rule.borderColor,
            colors: fillPalette,
            onSelected: (color) {
              _updateRule(
                rule,
                (current) => current.copyWith(borderColor: color),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateRule(
    _HighlightRule original,
    _HighlightRule Function(_HighlightRule current) update,
  ) {
    setState(() {
      final index =
          _highlightRules.indexWhere((item) => item.id == original.id);
      if (index == -1) return;
      _highlightRules[index] = update(_highlightRules[index]);
    });
  }

  List<_ResolvedHighlightMatch> _resolvedHighlightMatches({
    required String source,
    required HighlightTarget target,
  }) {
    final lowerSource = source.toLowerCase();
    final rawMatches = <_ResolvedHighlightMatch>[];

    for (var ruleIndex = 0; ruleIndex < _highlightRules.length; ruleIndex++) {
      final rule = _highlightRules[ruleIndex];
      if (rule.target != target) continue;
      final phrase = rule.phrase.trim();
      if (phrase.isEmpty) continue;

      final lowerPhrase = phrase.toLowerCase();
      var searchFrom = 0;
      final ruleMatches = <_ResolvedHighlightMatch>[];
      while (true) {
        final matchIndex = lowerSource.indexOf(lowerPhrase, searchFrom);
        if (matchIndex == -1) break;

        ruleMatches.add(
          _ResolvedHighlightMatch(
            start: matchIndex,
            end: matchIndex + phrase.length,
            ruleIndex: ruleIndex,
            rule: rule,
          ),
        );

        if (rule.matchMode == HighlightMatchMode.firstOnly) {
          break;
        }

        searchFrom = matchIndex + phrase.length;
      }

      if (rule.matchMode == HighlightMatchMode.next) {
        if (ruleMatches.isNotEmpty) {
          final selectedIndex = rule.occurrenceIndex % ruleMatches.length;
          rawMatches.add(ruleMatches[selectedIndex]);
        }
      } else {
        rawMatches.addAll(ruleMatches);
      }
    }

    rawMatches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;

      final aLength = a.end - a.start;
      final bLength = b.end - b.start;
      final byLength = bLength.compareTo(aLength);
      if (byLength != 0) return byLength;

      return a.ruleIndex.compareTo(b.ruleIndex);
    });

    final resolved = <_ResolvedHighlightMatch>[];
    var cursor = 0;
    for (final match in rawMatches) {
      if (match.start < cursor) continue;
      resolved.add(match);
      cursor = match.end;
    }

    return resolved;
  }

  String _presetLabel(HighlightPreset preset) {
    switch (preset) {
      case HighlightPreset.emphasis:
        return context.t('verse_share.preset_emphasis', fallback: 'Emphasis');
      case HighlightPreset.outline:
        return context.t('verse_share.preset_outline', fallback: 'Outline');
    }
  }

  List<Shadow> _buildHighlightShadows({
    required Color borderColor,
    required HighlightPreset preset,
  }) {
    switch (preset) {
      case HighlightPreset.emphasis:
        return [
          Shadow(
            color: borderColor.withValues(alpha: 0.35),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ];
      case HighlightPreset.outline:
        return [
          Shadow(color: borderColor, offset: const Offset(-1.2, 0)),
          Shadow(color: borderColor, offset: const Offset(1.2, 0)),
          Shadow(color: borderColor, offset: const Offset(0, -1.2)),
          Shadow(color: borderColor, offset: const Offset(0, 1.2)),
        ];
    }
  }

  _PresetVisualStyle _presetVisualStyle(HighlightPreset preset) {
    switch (preset) {
      case HighlightPreset.emphasis:
        return const _PresetVisualStyle(
          fillOpacity: 0.30,
          letterSpacing: 0.2,
        );
      case HighlightPreset.outline:
        return const _PresetVisualStyle(
          fillOpacity: 0.20,
          letterSpacing: 0.1,
        );
    }
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

class _HighlightRule {
  const _HighlightRule({
    required this.id,
    required this.phrase,
    required this.target,
    required this.preset,
    required this.fontStyleOption,
    required this.textColor,
    required this.fillColor,
    required this.borderColor,
    required this.fontStyleIndex,
    required this.sizeScale,
    required this.matchMode,
    required this.occurrenceIndex,
  });

  final String id;
  final String phrase;
  final HighlightTarget target;
  final HighlightPreset preset;
  final VerseFontStyleOption fontStyleOption;
  final Color textColor;
  final Color fillColor;
  final Color borderColor;
  final int fontStyleIndex;
  final double sizeScale;
  final HighlightMatchMode matchMode;
  final int occurrenceIndex;

  _HighlightRule copyWith({
    String? phrase,
    HighlightTarget? target,
    HighlightPreset? preset,
    VerseFontStyleOption? fontStyleOption,
    Color? textColor,
    Color? fillColor,
    Color? borderColor,
    int? fontStyleIndex,
    double? sizeScale,
    HighlightMatchMode? matchMode,
    int? occurrenceIndex,
  }) {
    return _HighlightRule(
      id: id,
      phrase: phrase ?? this.phrase,
      target: target ?? this.target,
      preset: preset ?? this.preset,
      fontStyleOption: fontStyleOption ?? this.fontStyleOption,
      textColor: textColor ?? this.textColor,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      fontStyleIndex: fontStyleIndex ?? this.fontStyleIndex,
      sizeScale: sizeScale ?? this.sizeScale,
      matchMode: matchMode ?? this.matchMode,
      occurrenceIndex: occurrenceIndex ?? this.occurrenceIndex,
    );
  }
}

class _ResolvedHighlightMatch {
  const _ResolvedHighlightMatch({
    required this.start,
    required this.end,
    required this.ruleIndex,
    required this.rule,
  });

  final int start;
  final int end;
  final int ruleIndex;
  final _HighlightRule rule;
}

class _PresetVisualStyle {
  const _PresetVisualStyle({
    required this.fillOpacity,
    required this.letterSpacing,
  });

  final double fillOpacity;
  final double letterSpacing;
}

Widget _buildColorDot({
  required Color color,
  required bool isSelected,
  bool isClear = false,
}) {
  return Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isSelected ? Colors.black : Colors.grey.shade400,
        width: isSelected ? 2 : 1,
      ),
    ),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isClear ? Colors.transparent : color,
        border: Border.all(
          color: Colors.grey.shade400,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isClear)
            Icon(
              Icons.block,
              size: 20,
              color: Colors.grey.shade700,
            ),
          if (isSelected)
            Icon(
              Icons.check,
              size: 18,
              color: isClear
                  ? Colors.black
                  : color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
            ),
        ],
      ),
    ),
  );
}
