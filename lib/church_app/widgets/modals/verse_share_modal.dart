import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/file_download.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// The share editor intentionally feels like a story editor: preview first,
// controls second, and every highlighted word owns its own style.
enum ShareFormat { square, story }

enum BackgroundType { color, image }

enum VerseFontStyleOption { bold, normal, italic }

Future<void> showVerseShareModal(
  BuildContext context, {
  required String text,
  required String reference,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VerseShareModal(
        text: text,
        reference: reference,
      ),
    ),
  );
}

class VerseShareModal extends StatefulWidget {
  const VerseShareModal({
    super.key,
    required this.text,
    required this.reference,
  });

  final String text;
  final String reference;

  @override
  State<VerseShareModal> createState() => _VerseShareModalState();
}

class _VerseShareModalState extends State<VerseShareModal> {
  static const double _downloadScaleMultiplier = 3.6;

  final GlobalKey _previewKey = GlobalKey();
  late final TextEditingController _verseController;
  late final TextEditingController _referenceController;
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
  double _editorPanelFraction = 0.52;
  bool _editorPanelVisible = true;
  bool _isDownloading = false;

  PickedImageData? selectedImage;
  final List<_HighlightRule> _highlightRules = [];
  String? _activeHighlightRuleId;

  String get _verseText => _verseController.text.trim().isEmpty
      ? widget.text
      : _verseController.text.trim();

  String get _referenceText => _referenceController.text.trim().isEmpty
      ? widget.reference
      : _referenceController.text.trim();

  final List<Color> backgroundPalette = const [
    Color(0xFFF5E6E1),
    Color(0xFFD6E3E7),
    Color(0xFFDDE6DD),
    Color(0xFFE8E0F2),
    Color(0xFFF3E4DC),
    Color(0xFF1C1C2E),
  ];

  final List<Color> fontPalette = const [
    Colors.transparent,
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
  ];

  final List<Color> fillPalette = const [
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
      fontFamily: null,
    ),
    _FontStyleOption(
      labelKey: 'verse_share.serif_font',
      fallback: 'Serif',
      fontFamily: 'serif',
    ),
    _FontStyleOption(
      labelKey: 'verse_share.sans_font',
      fallback: 'Sans',
      fontFamily: 'sans-serif',
    ),
    _FontStyleOption(
      labelKey: 'verse_share.mono_font',
      fallback: 'Mono',
      fontFamily: 'monospace',
    ),
    _FontStyleOption(
      labelKey: 'verse_share.rounded_font',
      fallback: 'Rounded',
      fontFamily: 'Roboto',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _verseController = TextEditingController(text: widget.text);
    _referenceController = TextEditingController(text: widget.reference);
  }

  @override
  void dispose() {
    _verseController.dispose();
    _referenceController.dispose();
    _storyCaptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.t('common.close', fallback: 'Close'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Verse Story Editor'),
        actions: [
          IconButton(
            tooltip: context.t('common.download', fallback: 'Download'),
            onPressed: _isDownloading ? null : downloadImage,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height;
            final panelHeight = screenHeight * _editorPanelFraction;
            final bottomReserve =
                (_editorPanelVisible ? panelHeight : 54.0) + 80.0;
            final previewHeight =
                math.max(240.0, screenHeight - bottomReserve - 18.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(0, 12, 0, bottomReserve),
                    child: RepaintBoundary(
                      key: _previewKey,
                      child: _buildPreview(previewHeight),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: _editorPanelVisible ? 76 : -panelHeight,
                  child: _buildInlineEditorPanel(
                    height: panelHeight,
                    screenHeight: screenHeight,
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  bottom: _editorPanelVisible ? -68 : 76,
                  child: _buildCollapsedEditorButton(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : downloadImage,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      context.t('common.download', fallback: 'Download'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _resizeEditorPanel(DragUpdateDetails details, double screenHeight) {
    setState(() {
      _editorPanelFraction =
          (_editorPanelFraction - details.delta.dy / screenHeight)
              .clamp(0.28, 0.95);
    });
  }

  Widget _buildInlineEditorPanel({
    required double height,
    required double screenHeight,
  }) {
    return DefaultTabController(
      length: 3,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  _resizeEditorPanel(details, screenHeight);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _editorPanelVisible = false);
                        },
                        icon:
                            const Icon(Icons.visibility_off_rounded, size: 18),
                        label: const Text('Hide'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        text: context.t(
                          'verse_share.layout',
                          fallback: 'Edit',
                        ),
                      ),
                      Tab(
                        text: context.t(
                          'verse_share.style',
                          fallback: 'Style',
                        ),
                      ),
                      Tab(
                        text: context.t(
                          'verse_share.footer',
                          fallback: 'Footer',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TabBarView(
                    children: [
                      _buildLayoutTab(),
                      _buildStyleTab(),
                      _buildFooterTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedEditorButton() {
    return FilledButton.icon(
      onPressed: () => setState(() => _editorPanelVisible = true),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.tune_rounded),
      label: const Text('Show editor'),
    );
  }

  Widget _buildPreview(double height) {
    final storyCaption = _storyCaptionController.text.trim();
    final footerHeight = _reservedFooterHeight(storyCaption);
    final aspectRatio = format == ShareFormat.square ? 1.0 : 9 / 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.max(0.0, constraints.maxWidth - 40);
        final targetHeight = math.min(height, maxWidth / aspectRatio);
        final targetWidth = targetHeight * aspectRatio;

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: backgroundType == BackgroundType.image ? pickImage : null,
            child: Container(
              height: targetHeight,
              width: targetWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: backgroundType == BackgroundType.color
                    ? backgroundColor
                    : Colors.grey.shade200,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (backgroundType == BackgroundType.image &&
                        selectedImage != null)
                      Image.memory(selectedImage!.bytes, fit: BoxFit.cover),
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
                          format == ShareFormat.story ? 18 : 24,
                          format == ShareFormat.story ? 44 : 28,
                          format == ShareFormat.story ? 18 : 24,
                          footerHeight + 12,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fittedSize = _fitVerseTextSize(
                              maxWidth: constraints.maxWidth,
                              maxHeight: constraints.maxHeight,
                            );
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: _buildVerseInlineSpans(
                                              fittedSize),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: fittedSize * 0.8),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '- ',
                                              style: _referenceTextStyle(
                                                fittedSize,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _referenceText,
                                              style: _referenceTextStyle(
                                                fittedSize,
                                              ),
                                            ),
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
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: Colors.white,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Tap to select image',
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
                          maxWidth: format == ShareFormat.story ? 150 : 220,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _todayDateLabel(),
                              style: _footerTextStyle(
                                fontSize: format == ShareFormat.story ? 12 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (format == ShareFormat.story &&
                                storyCaption.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                storyCaption,
                                style: _footerTextStyle(
                                  fontSize: 12,
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
                    const Positioned(
                      bottom: 12,
                      right: 12,
                      child: Opacity(
                        opacity: 0.85,
                        child: _VerseShareBranding(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: context.t('verse_share.layout', fallback: 'Edit'),
            description: 'Update the verse text and card size.',
            child: Column(
              children: [
                AppTextField(
                  controller: _verseController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Verse text'),
                  onChanged: (_) => setState(() {
                    _highlightRules.clear();
                    _activeHighlightRuleId = null;
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Square'),
                        selected: format == ShareFormat.square,
                        onSelected: (_) {
                          setState(() => format = ShareFormat.square);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Story'),
                        selected: format == ShareFormat.story,
                        onSelected: (_) {
                          setState(() => format = ShareFormat.story);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Color'),
                        selected: backgroundType == BackgroundType.color,
                        onSelected: (_) {
                          setState(() => backgroundType = BackgroundType.color);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Image'),
                        selected: backgroundType == BackgroundType.image,
                        onSelected: (_) {
                          setState(() => backgroundType = BackgroundType.image);
                          if (selectedImage == null) pickImage();
                        },
                      ),
                    ),
                  ],
                ),
                if (backgroundType == BackgroundType.color) ...[
                  const SizedBox(height: 16),
                  _buildColorPaletteSection(
                    title: 'Background color',
                    selectedColor: backgroundColor,
                    colors: backgroundPalette,
                    onSelected: (color) {
                      setState(() => backgroundColor = color);
                    },
                  ),
                ],
                if (backgroundType == BackgroundType.image) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Choose image'),
                  ),
                  const SizedBox(height: 8),
                  Text('Blur: ${blurIntensity.toStringAsFixed(0)}'),
                  Slider(
                    value: blurIntensity,
                    min: 0,
                    max: 24,
                    onChanged: (value) {
                      setState(() => blurIntensity = value);
                    },
                  ),
                ],
              ],
            ),
          ),
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
            title: 'Base verse style',
            description:
                'This applies to the full verse unless a highlighted word overrides it.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDropdownField<int>(
                  initialValue: selectedFontStyleIndex,
                  labelText: 'Font',
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
                    setState(() => selectedFontStyleIndex = value);
                  },
                ),
                const SizedBox(height: 12),
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
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Bold'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Normal'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Italic'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Size: ${fontSize.toStringAsFixed(0)}'),
                Slider(
                  value: fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  onChanged: (value) => setState(() => fontSize = value),
                ),
                _buildColorPaletteSection(
                  title: 'Font color',
                  selectedColor: fontColor,
                  colors: fontPalette,
                  onSelected: (color) => setState(() => fontColor = color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: context.t('verse_share.highlights', fallback: 'Highlights'),
            description:
                'Tap words, then style each selected word differently.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHighlightWordSelector(),
                const SizedBox(height: 14),
                _buildSelectedHighlightsSummary(),
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
          _buildColorPaletteSection(
            title:
                context.t('verse_share.footer_color', fallback: 'Footer Color'),
            selectedColor: footerColor,
            colors: fontPalette,
            onSelected: (color) => setState(() => footerColor = color),
          ),
          const SizedBox(height: 20),
          if (format == ShareFormat.story)
            AppTextField(
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
              onChanged: (_) => setState(() {}),
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
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final imageData = await PickedImageData.fromXFile(file);
    if (imageData == null) return;
    setState(() {
      selectedImage = imageData;
      backgroundType = BackgroundType.image;
    });
  }

  Future<void> downloadImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = _previewKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        _showDownloadMessage('Preview is not ready yet. Please try again.');
        return;
      }

      final image = await renderObject.toImage(
        pixelRatio: _downloadScaleMultiplier,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) {
        _showDownloadMessage('Unable to prepare image. Please try again.');
        return;
      }

      final filename =
          'verse-${DateTime.now().millisecondsSinceEpoch.toString()}.png';
      if (kIsWeb) {
        downloadBytes(
          bytes: pngBytes,
          fileName: filename,
          mimeType: 'image/png',
        );
      } else {
        await Gal.putImageBytes(pngBytes, name: filename);
      }

      if (mounted) {
        _showDownloadMessage('Verse image saved.');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        _showDownloadMessage('Unable to save image. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showDownloadMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  TextStyle _textStyle(double size) {
    final selectedFont = fontStyleOptions[selectedFontStyleIndex];
    return TextStyle(
      fontSize: size,
      fontWeight: _resolvedFontWeight(),
      color: fontColor,
      fontFamily: selectedFont.fontFamily,
      fontStyle: _resolvedFontStyle(),
      height: 1.28,
    );
  }

  List<InlineSpan> _buildVerseInlineSpans(double size) {
    final matches = _resolvedHighlightMatches(_verseText);
    if (matches.isEmpty) {
      return [TextSpan(text: _verseText, style: _textStyle(size))];
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: _verseText.substring(cursor, match.start),
            style: _textStyle(size),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: _verseText.substring(match.start, match.end),
          style: _highlightTextStyle(rule: match.rule, size: size),
        ),
      );
      cursor = match.end;
    }
    if (cursor < _verseText.length) {
      spans.add(TextSpan(
          text: _verseText.substring(cursor), style: _textStyle(size)));
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
    final hasFill = rule.fillColor != Colors.transparent;
    return TextStyle(
      fontSize: size * rule.sizeScale,
      color: rule.textColor,
      fontFamily: selectedFont.fontFamily,
      fontStyle: rule.fontStyleOption == VerseFontStyleOption.italic
          ? FontStyle.italic
          : FontStyle.normal,
      fontWeight: rule.fontStyleOption == VerseFontStyleOption.bold
          ? FontWeight.w800
          : FontWeight.w500,
      letterSpacing: 0.15,
      backgroundColor:
          hasFill ? rule.fillColor.withValues(alpha: 0.24) : Colors.transparent,
      shadows: _buildHighlightBorderShadows(rule.borderColor),
      decoration: TextDecoration.none,
      height: 1.28,
    );
  }

  List<Shadow> _buildHighlightBorderShadows(Color borderColor) {
    if (borderColor == Colors.transparent) return const [];
    final outline = borderColor.withValues(alpha: 0.75);
    return [
      Shadow(color: outline, offset: const Offset(-1, 0)),
      Shadow(color: outline, offset: const Offset(1, 0)),
      Shadow(color: outline, offset: const Offset(0, -1)),
      Shadow(color: outline, offset: const Offset(0, 1)),
      Shadow(
        color: borderColor.withValues(alpha: 0.28),
        offset: const Offset(0, 1.5),
        blurRadius: 3,
      ),
    ];
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

  TextStyle _footerTextStyle({
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    return TextStyle(
      color: footerColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  double _reservedFooterHeight(String storyCaption) {
    if (format == ShareFormat.story && storyCaption.isNotEmpty) return 68;
    return 46;
  }

  double _fitVerseTextSize(
      {required double maxWidth, required double maxHeight}) {
    final candidate = fontSize;
    final painter = TextPainter(
      text: TextSpan(
        children: [
          ..._buildVerseInlineSpans(candidate),
          TextSpan(
              text: '\n- $_referenceText',
              style: _referenceTextStyle(candidate)),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    if (painter.height <= maxHeight) return candidate;
    final scale = (maxHeight / painter.height).clamp(0.62, 1.0);
    return candidate * scale;
  }

  String _todayDateLabel() => DateFormat('dd/MM/yyyy').format(DateTime.now());

  Widget _buildSectionCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
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
          Text(description, style: Theme.of(context).textTheme.bodySmall),
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildHighlightWordSelector() {
    final tokens = _highlightableTokens();
    if (tokens.isEmpty) {
      return Text(
        'Type verse text first, then tap words here to highlight.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any word to highlight it',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Every selected word gets its own style controls below.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tokens.map((token) {
              final selected = _isTokenHighlighted(token);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _toggleHighlightToken(token),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.14)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.add_circle_outline_rounded,
                          size: 17,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          token.text,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedHighlightsSummary() {
    if (_highlightRules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(
                  'verse_share.highlights_empty',
                  fallback: 'No highlighted words yet.',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final activeRule = _highlightRules.firstWhere(
      (rule) => rule.id == _activeHighlightRuleId,
      orElse: () => _highlightRules.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Selected highlights',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _highlightRules.clear();
                  _activeHighlightRuleId = null;
                });
              },
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _highlightRules.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final rule = _highlightRules[index];
              final isActive = rule.id == activeRule.id;
              return ChoiceChip(
                selected: isActive,
                label: Text(rule.phrase),
                avatar: CircleAvatar(
                  radius: 8,
                  backgroundColor: rule.textColor,
                ),
                onSelected: (_) {
                  setState(() {
                    _activeHighlightRuleId = rule.id;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildHighlightWordStyleCard(activeRule),
      ],
    );
  }

  Widget _buildHighlightWordStyleCard(_HighlightRule rule) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: rule.fillColor == Colors.transparent
                        ? rule.textColor.withValues(alpha: 0.12)
                        : rule.fillColor.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: rule.borderColor == Colors.transparent
                          ? rule.textColor.withValues(alpha: 0.35)
                          : rule.borderColor,
                    ),
                  ),
                  child: Text(
                    rule.phrase,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: rule.textColor,
                          fontWeight: FontWeight.w800,
                          fontStyle: rule.fontStyleOption ==
                                  VerseFontStyleOption.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: context.t('common.delete', fallback: 'Delete'),
                onPressed: () => _removeHighlightRule(rule),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppDropdownField<int>(
            initialValue: rule.fontStyleIndex,
            labelText: context.t(
              'verse_share.highlight_font',
              fallback: 'Highlight Font',
            ),
            items: List.generate(fontStyleOptions.length, (index) {
              final option = fontStyleOptions[index];
              return DropdownMenuItem(
                value: index,
                child:
                    Text(context.t(option.labelKey, fallback: option.fallback)),
              );
            }),
            onChanged: (value) {
              if (value == null) return;
              _updateHighlightRule(
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
              _updateHighlightRule(
                rule,
                (current) => current.copyWith(
                  fontStyleOption: VerseFontStyleOption.values[index],
                ),
              );
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Bold'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Normal'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Italic'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scale: ${rule.sizeScale.toStringAsFixed(2)}x',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: rule.sizeScale,
            min: 0.85,
            max: 1.35,
            divisions: 10,
            label: rule.sizeScale.toStringAsFixed(2),
            onChanged: (value) {
              _updateHighlightRule(
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
            colors: fillPalette.where((color) {
              return color != Colors.transparent;
            }).toList(growable: false),
            onSelected: (color) {
              _updateHighlightRule(
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
              _updateHighlightRule(
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
              _updateHighlightRule(
                rule,
                (current) => current.copyWith(borderColor: color),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateHighlightRule(
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

  List<_HighlightToken> _highlightableTokens() {
    return _tokensForSource(_verseText);
  }

  bool _isTokenHighlighted(_HighlightToken token) {
    return _highlightRules.any(
      (rule) => rule.sourceStart == token.start && rule.sourceEnd == token.end,
    );
  }

  void _toggleHighlightToken(_HighlightToken token) {
    final existingRuleIndex = _highlightRules.indexWhere(
      (rule) => rule.sourceStart == token.start && rule.sourceEnd == token.end,
    );
    if (existingRuleIndex != -1) {
      final removedRule = _highlightRules[existingRuleIndex];
      setState(() {
        _highlightRules.removeAt(existingRuleIndex);
        if (_activeHighlightRuleId == removedRule.id) {
          _activeHighlightRuleId =
              _highlightRules.isEmpty ? null : _highlightRules.first.id;
        }
      });
      return;
    }
    _addHighlightRule(token);
  }

  void _addHighlightRule(_HighlightToken token) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.red,
      Colors.black,
    ];
    final color = colors[_highlightRules.length % colors.length];
    setState(() {
      final rule = _HighlightRule(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        phrase: token.text,
        sourceStart: token.start,
        sourceEnd: token.end,
        fontStyleOption: VerseFontStyleOption.bold,
        textColor: color,
        fillColor: Colors.transparent,
        borderColor: color.withValues(alpha: 0.55),
        fontStyleIndex: selectedFontStyleIndex,
        sizeScale: 1.0,
      );
      _highlightRules.add(rule);
      _activeHighlightRuleId = rule.id;
    });
  }

  void _removeHighlightRule(_HighlightRule rule) {
    setState(() {
      _highlightRules.removeWhere((item) => item.id == rule.id);
      if (_activeHighlightRuleId == rule.id) {
        _activeHighlightRuleId =
            _highlightRules.isEmpty ? null : _highlightRules.first.id;
      }
    });
  }

  List<_ResolvedHighlightMatch> _resolvedHighlightMatches(String source) {
    final rawMatches = <_ResolvedHighlightMatch>[];
    for (var ruleIndex = 0; ruleIndex < _highlightRules.length; ruleIndex++) {
      final rule = _highlightRules[ruleIndex];
      final exactStart = rule.sourceStart;
      final exactEnd = rule.sourceEnd;
      if (exactStart != null &&
          exactEnd != null &&
          exactStart >= 0 &&
          exactEnd <= source.length &&
          exactStart < exactEnd &&
          _normalizeHighlightText(source.substring(exactStart, exactEnd)) ==
              _normalizeHighlightText(rule.phrase)) {
        rawMatches.add(
          _ResolvedHighlightMatch(
            start: exactStart,
            end: exactEnd,
            ruleIndex: ruleIndex,
            rule: rule,
          ),
        );
        continue;
      }

      for (final token in _tokensForSource(source)) {
        if (_normalizeHighlightText(token.text) !=
            _normalizeHighlightText(rule.phrase)) {
          continue;
        }
        rawMatches.add(
          _ResolvedHighlightMatch(
            start: token.start,
            end: token.end,
            ruleIndex: ruleIndex,
            rule: rule,
          ),
        );
      }
    }

    rawMatches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      final byLength = (b.end - b.start).compareTo(a.end - a.start);
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

  List<_HighlightToken> _tokensForSource(String source) {
    return RegExp(r"[\p{L}\p{M}\p{N}'’]+", unicode: true)
        .allMatches(source)
        .map((match) {
          return _HighlightToken(
            text: match.group(0)?.trim() ?? '',
            start: match.start,
            end: match.end,
          );
        })
        .where((token) => token.text.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeHighlightText(String value) => value.trim().toLowerCase();
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
  const _BrandText({required this.appTitle});

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
  const _FontStyleOption({
    required this.labelKey,
    required this.fallback,
    required this.fontFamily,
  });

  final String labelKey;
  final String fallback;
  final String? fontFamily;
}

class _HighlightRule {
  const _HighlightRule({
    required this.id,
    required this.phrase,
    required this.sourceStart,
    required this.sourceEnd,
    required this.fontStyleOption,
    required this.textColor,
    required this.fillColor,
    required this.borderColor,
    required this.fontStyleIndex,
    required this.sizeScale,
  });

  final String id;
  final String phrase;
  final int? sourceStart;
  final int? sourceEnd;
  final VerseFontStyleOption fontStyleOption;
  final Color textColor;
  final Color fillColor;
  final Color borderColor;
  final int fontStyleIndex;
  final double sizeScale;

  _HighlightRule copyWith({
    String? phrase,
    int? sourceStart,
    int? sourceEnd,
    VerseFontStyleOption? fontStyleOption,
    Color? textColor,
    Color? fillColor,
    Color? borderColor,
    int? fontStyleIndex,
    double? sizeScale,
  }) {
    return _HighlightRule(
      id: id,
      phrase: phrase ?? this.phrase,
      sourceStart: sourceStart ?? this.sourceStart,
      sourceEnd: sourceEnd ?? this.sourceEnd,
      fontStyleOption: fontStyleOption ?? this.fontStyleOption,
      textColor: textColor ?? this.textColor,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      fontStyleIndex: fontStyleIndex ?? this.fontStyleIndex,
      sizeScale: sizeScale ?? this.sizeScale,
    );
  }
}

class _HighlightToken {
  const _HighlightToken({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final int start;
  final int end;
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
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isClear) Icon(Icons.block, size: 20, color: Colors.grey.shade700),
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
