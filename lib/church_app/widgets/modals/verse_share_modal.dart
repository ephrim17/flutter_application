import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/file_download.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/models/verse_image_template.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/widgets/app_confirm_dialog.dart';
import 'package:flutter_application/church_app/widgets/app_modal_bottom_sheet.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// The share editor intentionally feels like a story editor: preview first,
// controls second, and every highlighted word owns its own style.
enum ShareFormat { square, story }

enum BackgroundType { color, image }

enum VerseFontStyleOption { bold, normal, italic }

class _DateStyleOption {
  const _DateStyleOption({required this.pattern});

  final String pattern;
}

const _dateStyleOptions = [
  _DateStyleOption(pattern: 'dd/MM/yyyy'),
  _DateStyleOption(pattern: 'd MMM yyyy'),
  _DateStyleOption(pattern: 'MMMM d, yyyy'),
  _DateStyleOption(pattern: 'EEEE, MMM d'),
  _DateStyleOption(pattern: 'yyyy.MM.dd'),
];

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

/// Entry point for verse sharing: asks whether to generate a background with
/// AI or build the card manually, then routes to the matching flow. Replaces
/// direct calls to [showVerseShareModal] at every share-icon call site.
Future<void> showVerseShareChoiceSheet(
  BuildContext context, {
  required String text,
  required String reference,
}) async {
  final choice = await showAppModalBottomSheet<_VerseShareChoice>(
    context: context,
    builder: (sheetContext) => _VerseShareChoiceSheet(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _VerseShareChoice.ai:
      await _startAiVerseShareFlow(context, text: text, reference: reference);
    case _VerseShareChoice.manual:
      await showVerseShareModal(context, text: text, reference: reference);
  }
}

enum _VerseShareChoice { ai, manual }

class _VerseShareChoiceSheet extends StatelessWidget {
  const _VerseShareChoiceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('ui.verse_share.choice_title'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          _VerseShareChoiceTile(
            icon: Icons.auto_awesome_rounded,
            title: context.t('ui.verse_share.generate_with_ai'),
            subtitle: context.t('ui.verse_share.generate_with_ai_subtitle'),
            onTap: () =>
                Navigator.of(context).pop(_VerseShareChoice.ai),
          ),
          const SizedBox(height: 12),
          _VerseShareChoiceTile(
            icon: Icons.edit_rounded,
            title: context.t('ui.verse_share.create_manually'),
            subtitle: context.t('ui.verse_share.create_manually_subtitle'),
            onTap: () =>
                Navigator.of(context).pop(_VerseShareChoice.manual),
          ),
        ],
      ),
    );
  }
}

class _VerseShareChoiceTile extends StatelessWidget {
  const _VerseShareChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Calls the backend for up to 3 complete AI-generated verse-card
/// candidates (verse text, church name and date all rendered into the
/// image by Gemini itself), then shows them full-screen and swipeable so
/// the person can compare and download whichever they land on — no
/// further app-side editing, since each candidate is already final.
Future<void> _startAiVerseShareFlow(
  BuildContext context, {
  required String text,
  required String reference,
}) async {
  final images = await showDialog<List<PickedImageData>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AiVerseImageGenerationDialog(
      text: text,
      reference: reference,
    ),
  );
  if (images == null || images.isEmpty || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _AiVerseCardSwipeScreen(images: images),
    ),
  );
}

class _AiVerseImageGenerationDialog extends ConsumerStatefulWidget {
  const _AiVerseImageGenerationDialog({
    required this.text,
    required this.reference,
  });

  final String text;
  final String reference;

  @override
  ConsumerState<_AiVerseImageGenerationDialog> createState() =>
      _AiVerseImageGenerationDialogState();
}

class _AiVerseImageGenerationDialogState
    extends ConsumerState<_AiVerseImageGenerationDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
  }

  Future<void> _generate() async {
    try {
      // The full church name (not the short Studio-configured app title
      // abbreviation, e.g. "T.N.B.M") — Gemini renders its own decorative
      // banner, which has room for the real name, unlike the small on-screen
      // branding pill in the manual editor that still uses the abbreviation.
      final churchName = ref.read(selectedChurchProvider)?.name.trim() ?? '';
      final contactNumber = ref.read(selectedChurchProvider)?.contact ?? '';
      final dateLabel = DateFormat('d MMMM yyyy').format(DateTime.now());
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('generateVerseBackgroundImage').call<Map<String, dynamic>>({
        'verseText': widget.text,
        'reference': widget.reference,
        'churchName': churchName,
        'contactNumber': contactNumber,
        'dateLabel': dateLabel,
      });
      final rawImages = (result.data['images'] as List?) ?? const [];
      final images = rawImages
          .whereType<Map>()
          .map((item) => item['data'] as String?)
          .whereType<String>()
          .map(
            (data) => PickedImageData(
              bytes: base64Decode(data),
              name: 'ai-verse-${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      if (images.isEmpty) {
        Navigator.of(context).pop();
        _showErrorSnackBar(context, context.t('ui.verse_share.ai_generation_failed'));
        return;
      }
      Navigator.of(context).pop(images);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final key = e.message == 'quota-exceeded'
          ? 'ui.verse_share.ai_quota_exceeded'
          : 'ui.verse_share.ai_generation_failed';
      _showErrorSnackBar(context, context.t(key));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showErrorSnackBar(context, context.t('ui.verse_share.ai_generation_failed'));
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(context.t('ui.verse_share.generating_image')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows every already-complete AI-generated verse card (verse text,
/// church name and date all baked into the image by Gemini) full-screen
/// and swipeable, with a page indicator, and downloads whichever candidate
/// is currently visible — no further app-side compositing needed, since
/// each candidate is already final.
class _AiVerseCardSwipeScreen extends StatefulWidget {
  const _AiVerseCardSwipeScreen({required this.images});

  final List<PickedImageData> images;

  @override
  State<_AiVerseCardSwipeScreen> createState() =>
      _AiVerseCardSwipeScreenState();
}

class _AiVerseCardSwipeScreenState extends State<_AiVerseCardSwipeScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _isDownloading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = widget.images[_page].bytes;
      final filename = 'verse-${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (kIsWeb) {
        downloadBytes(
          bytes: bytes,
          fileName: filename,
          mimeType: 'image/jpeg',
        );
      } else {
        await Gal.putImageBytes(bytes, name: filename);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('ui.verse_share.image_saved')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('AI verse image download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('ui.verse_share.download_failed')),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: context.t('common.close'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: widget.images.length > 1
            ? Text(
                context.t(
                  'common.image_position',
                  parameters: {
                    'current': _page + 1,
                    'total': widget.images.length,
                  },
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) => Center(
              child: Image.memory(
                widget.images[index].bytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: index == _page ? 20 : 6,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: index == _page ? 0.95 : 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDownloading ? null : _download,
              icon: _isDownloading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(context.t('common.download')),
            ),
          ),
        ),
      ),
    );
  }
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
  VerseLayoutKind layout = VerseLayoutKind.centered;

  Color backgroundColor = const Color(0xFFD6E3E7);
  Color fontColor = Colors.black;
  Color footerColor = Colors.black;

  double fontSize = 20;
  VerseFontStyleOption fontStyleOption = VerseFontStyleOption.bold;
  double blurIntensity = 10;
  bool _editorPanelVisible = false;
  bool _showFullPreview = false;
  String _dateFormatPattern = _dateStyleOptions.first.pattern;
  bool _isDownloading = false;

  PickedImageData? selectedImage;
  final List<_HighlightRule> _highlightRules = [];
  String? _activeHighlightRuleId;
  String? _selectedTemplateId;
  bool _isApplyingTemplate = false;

  String get _verseText => _verseController.text.trim().isEmpty
      ? widget.text
      : _verseController.text.trim();

  String get _referenceText => _referenceController.text.trim().isEmpty
      ? widget.reference
      : _referenceController.text.trim();

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
      appBar: _showFullPreview
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: context.t('common.close'),
                onPressed: _handleClosePressed,
                icon: const Icon(Icons.close_rounded),
              ),
              title: Text(context.t('ui.verse_share.verse_story_editor')),
              actions: [
                IconButton(
                  tooltip: context.t('ui.verse_share.preview'),
                  onPressed: () => setState(() => _showFullPreview = true),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              ],
            ),
      body: SafeArea(
        child: _showFullPreview
            ? _buildFullPreviewOverlay()
            : LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height;
            final panelHeight = screenHeight;
            final bottomReserve = _editorPanelVisible ? 24.0 : 54.0 + 16.0;
            const stripsHeight = 104.0 + 88.0;
            final previewHeight = math.max(
              200.0,
              screenHeight - bottomReserve - 18.0 - stripsHeight,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(0, 12, 0, bottomReserve),
                    child: Column(
                      children: [
                        _buildTemplateStrip(),
                        const SizedBox(height: 8),
                        _buildLayoutStrip(),
                        const SizedBox(height: 12),
                        RepaintBoundary(
                          key: _previewKey,
                          child: _buildPreview(previewHeight),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: _editorPanelVisible ? 0 : -panelHeight,
                  height: panelHeight,
                  child: _buildInlineEditorPanel(),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: 16,
                  right: 16,
                  bottom: _editorPanelVisible ? -70 : 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFrostedActionButton(
                          icon: Icons.tune_rounded,
                          label: context.t('ui.verse_share.show_editor'),
                          onPressed: () =>
                              setState(() => _editorPanelVisible = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFrostedActionButton(
                          icon: Icons.download_rounded,
                          label: context.t('common.download'),
                          busy: _isDownloading,
                          onPressed: _isDownloading ? null : downloadImage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleClosePressed() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: context.t('verse_share.discard_title'),
      message: context.t('verse_share.discard_message'),
      confirmLabel: context.t('common.discard'),
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).maybePop();
  }

  Widget _buildInlineEditorPanel() {
    return DefaultTabController(
      length: 3,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: 0.6,
                  ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 250) {
                      setState(() => _editorPanelVisible = false);
                    }
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
                        IconButton(
                          tooltip: context.t('ui.verse_share.hide'),
                          onPressed: () {
                            setState(() => _editorPanelVisible = false);
                          },
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.only(right: 28),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.onSurface,
                    unselectedLabelColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    tabs: [
                      Tab(
                        text: context.t('verse_share.layout'),
                      ),
                      Tab(
                        text: context.t('verse_share.style'),
                      ),
                      Tab(
                        text: context.t('verse_share.footer'),
                      ),
                    ],
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
      ),
    );
  }

  /// Compact frosted-glass pill — deliberately smaller and translucent
  /// rather than a full-width solid button, so the two actions sit side by
  /// side without eating into the preview's vertical space.
  Widget _buildFrostedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool busy = false,
  }) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: theme.colorScheme.surface.withValues(alpha: 0.55),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: theme.colorScheme.onSurface),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateStrip() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: verseImageTemplates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final template = verseImageTemplates[index];
          final selected = _selectedTemplateId == template.id;
          return GestureDetector(
            onTap: () => _applyTemplate(template),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(template.assetPath, fit: BoxFit.cover),
                        if (selected && _isApplyingTemplate)
                          Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Center(
                              child: SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(template.nameKey),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayoutStrip() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: verseLayoutStyles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final style = verseLayoutStyles[index];
          final selected = layout == style.kind;
          return GestureDetector(
            onTap: () => _applyLayout(style.kind),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected
                        ? Theme.of(context).colorScheme.primary.withValues(
                              alpha: 0.14,
                            )
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor.withValues(
                                alpha: 0.18,
                              ),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Icon(
                    style.icon,
                    size: 22,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(style.nameKey),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreview(double height, {bool interactive = true}) {
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
            onTap: interactive && backgroundType == BackgroundType.image
                ? pickImage
                : null,
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
                    _buildVerseTextArea(footerHeight),
                    if (backgroundType == BackgroundType.image &&
                        selectedImage == null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.grey.withValues(alpha: 0.65),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: Colors.white,
                              ),
                              SizedBox(height: 12),
                              Text(
                                context.t('ui.verse_share.tap_to_select_image'),
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

  Widget _buildFullPreviewOverlay() {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showFullPreview = false),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: _buildPreview(
                MediaQuery.of(context).size.height * 0.75,
                interactive: false,
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: IconButton(
                tooltip: context.t('ui.verse_share.preview'),
                onPressed: () => setState(() => _showFullPreview = false),
                icon: const Icon(Icons.visibility_outlined),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerseTextArea(double footerHeight) {
    if (layout == VerseLayoutKind.splitCorners) {
      return _buildSplitCornersArea(footerHeight);
    }

    final cornerAnchored = layout == VerseLayoutKind.cornerAnchored;
    final sideBar = layout == VerseLayoutKind.sideBarAccent;
    final alignment = cornerAnchored ? Alignment.topCenter : Alignment.center;
    final crossAxis =
        sideBar ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = sideBar ? TextAlign.left : TextAlign.center;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          format == ShareFormat.story ? 18 : 24,
          cornerAnchored
              ? (format == ShareFormat.story ? 64 : 40)
              : (format == ShareFormat.story ? 44 : 28),
          format == ShareFormat.story ? 18 : 24,
          cornerAnchored ? 12 : footerHeight + 12,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fittedSize = _fitVerseTextSize(
              maxWidth: constraints.maxWidth,
              maxHeight: constraints.maxHeight,
            );
            final verseText = Text.rich(
              TextSpan(children: _buildVerseInlineSpans(fittedSize)),
              textAlign: textAlign,
            );
            final referenceLine = _buildReferenceLine(
              fittedSize,
              align: textAlign,
            );

            Widget content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: crossAxis,
              children: [
                verseText,
                SizedBox(height: fittedSize * 0.8),
                switch (layout) {
                  VerseLayoutKind.dividerPill => Column(
                      crossAxisAlignment: crossAxis,
                      children: [
                        Container(
                          height: 1.5,
                          width: 64,
                          color: fontColor.withValues(alpha: 0.45),
                        ),
                        SizedBox(height: fittedSize * 0.5),
                        _buildReferencePill(fittedSize),
                      ],
                    ),
                  VerseLayoutKind.badgeCircle => _buildReferenceBadge(
                      fittedSize,
                    ),
                  VerseLayoutKind.archBanner => _buildReferenceRibbon(
                      fittedSize,
                    ),
                  _ => referenceLine,
                },
              ],
            );

            if (layout == VerseLayoutKind.boxedFrame) {
              content = _wrapInFramedPanel(content, fittedSize);
            } else if (layout == VerseLayoutKind.stackedCards) {
              content = _wrapInStackedCards(content, fittedSize);
            } else if (layout == VerseLayoutKind.quoteMark) {
              content = _wrapWithQuoteMark(content, fittedSize);
            } else if (layout == VerseLayoutKind.sideBarAccent) {
              content = _wrapWithSideBar(content);
            }

            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSplitCornersArea(double footerHeight) {
    return Padding(
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
            maxHeight: constraints.maxHeight * 0.6,
          );
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text.rich(
                    TextSpan(children: _buildVerseInlineSpans(fittedSize)),
                    textAlign: TextAlign.left,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: _buildReferenceLine(
                    fittedSize,
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferenceLine(double fittedSize, {TextAlign align = TextAlign.center}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '- ', style: _referenceTextStyle(fittedSize)),
          TextSpan(text: _referenceText, style: _referenceTextStyle(fittedSize)),
        ],
      ),
      textAlign: align,
    );
  }

  Widget _buildReferencePill(double fittedSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: fontColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _referenceText,
        style: _referenceTextStyle(fittedSize).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildReferenceBadge(double fittedSize) {
    final dimension = fittedSize * 3.4;
    return Container(
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      padding: EdgeInsets.all(fittedSize * 0.3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: fontColor.withValues(alpha: 0.6), width: 1.4),
      ),
      child: Text(
        _referenceText,
        textAlign: TextAlign.center,
        style: _referenceTextStyle(fittedSize).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildReferenceRibbon(double fittedSize) {
    return CustomPaint(
      painter: _RibbonPainter(
        fillColor: fontColor.withValues(alpha: 0.16),
        borderColor: fontColor.withValues(alpha: 0.55),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: fittedSize * 1.1,
          vertical: fittedSize * 0.4,
        ),
        child: Text(
          _referenceText,
          style: _referenceTextStyle(fittedSize).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _wrapInFramedPanel(Widget content, double fittedSize) {
    final panelColor = fontColor.computeLuminance() > 0.5
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.22);
    return Container(
      padding: EdgeInsets.all(fittedSize * 0.9),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fontColor.withValues(alpha: 0.5)),
      ),
      child: content,
    );
  }

  Widget _wrapInStackedCards(Widget content, double fittedSize) {
    final panelColor = fontColor.computeLuminance() > 0.5
        ? Colors.black.withValues(alpha: 0.24)
        : Colors.white.withValues(alpha: 0.2);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.05,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: fontColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(fittedSize * 0.9),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fontColor.withValues(alpha: 0.45)),
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _wrapWithQuoteMark(Widget content, double fittedSize) {
    return Padding(
      padding: EdgeInsets.only(top: fittedSize * 1.1),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -fittedSize * 1.1,
            child: Icon(
              Icons.format_quote_rounded,
              size: fittedSize * 2.2,
              color: fontColor.withValues(alpha: 0.18),
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _wrapWithSideBar(Widget content) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: fontColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(child: content),
        ],
      ),
    );
  }

  Widget _buildLayoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            description:
                context.t('ui.verse_share.update_the_verse_text_and_card_size'),
            child: Column(
              children: [
                AppTextField(
                  controller: _verseController,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: context.t('ui.verse_share.verse_text')),
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
                        label: Text(context.t('ui.verse_share.square')),
                        selected: format == ShareFormat.square,
                        onSelected: (_) {
                          setState(() => format = ShareFormat.square);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(context.t('ui.verse_share.story')),
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
                        label: Text(context.t('ui.verse_share.color')),
                        selected: backgroundType == BackgroundType.color,
                        onSelected: (_) {
                          setState(() {
                            backgroundType = BackgroundType.color;
                            _selectedTemplateId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(context.t('ui.verse_share.image')),
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
                  _buildColorSliderSection(
                    title: context.t('ui.verse_share.background_color'),
                    selectedColor: backgroundColor,
                    saturation: 0.55,
                    lightness: 0.82,
                    onChanged: (color) {
                      setState(() => backgroundColor = color);
                    },
                  ),
                ],
                if (backgroundType == BackgroundType.image) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image_rounded),
                    label: Text(context.t('ui.verse_share.choose_image')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'verse_share.blur_value',
                      parameters: {
                        'value': blurIntensity.toStringAsFixed(0),
                      },
                    ),
                  ),
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
            title: context.t('ui.verse_share.base_verse_style'),
            description: context.t(
                'ui.verse_share.this_applies_to_the_full_verse_unless_a_highlighted_'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(context.t('ui.verse_share.bold_425d')),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(context.t('ui.verse_share.normal_6dd2')),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(context.t('ui.verse_share.italic_fe26')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.t(
                    'verse_share.size_value',
                    parameters: {'value': fontSize.toStringAsFixed(0)},
                  ),
                ),
                Slider(
                  value: fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  onChanged: (value) => setState(() => fontSize = value),
                ),
                _buildColorSliderSection(
                  title: context.t('ui.verse_share.font_color'),
                  selectedColor: fontColor,
                  saturation: 0.65,
                  lightness: 0.42,
                  quickColors: const [Colors.black, Colors.white],
                  onChanged: (color) => setState(() => fontColor = color),
                ),
              ],
            ),
          ),
          _buildSectionCard(
            title: context.t('verse_share.highlights'),
            withTopDivider: true,
            description: context.t(
                'ui.verse_share.tap_words_then_style_each_selected_word_differently'),
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
            context.t(
              'verse_share.date_value',
              parameters: {'date': _todayDateLabel()},
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('verse_share.footer_date_note'),
          ),
          const SizedBox(height: 14),
          Text(
            context.t('verse_share.date_style'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dateStyleOptions.map((option) {
              final selected = _dateFormatPattern == option.pattern;
              return ChoiceChip(
                label: Text(
                  DateFormat(option.pattern).format(DateTime.now()),
                ),
                selected: selected,
                onSelected: (_) {
                  setState(() => _dateFormatPattern = option.pattern);
                },
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 20),
          _buildColorSliderSection(
            title: context.t('verse_share.footer_color'),
            selectedColor: footerColor,
            saturation: 0.65,
            lightness: 0.42,
            quickColors: const [Colors.black, Colors.white],
            onChanged: (color) => setState(() => footerColor = color),
          ),
          const SizedBox(height: 20),
          if (format == ShareFormat.story)
            AppTextField(
              controller: _storyCaptionController,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: context.t('verse_share.bottom_left_text_optional'),
                helperText: context.t('verse_share.story_footer_helper'),
              ),
              onChanged: (_) => setState(() {}),
            )
          else
            Text(
              context.t('verse_share.story_footer_note'),
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
      _selectedTemplateId = null;
    });
  }

  Future<void> _applyTemplate(VerseImageTemplate template) async {
    if (_isApplyingTemplate) return;
    setState(() => _isApplyingTemplate = true);
    try {
      final data = await rootBundle.load(template.assetPath);
      if (!mounted) return;
      setState(() {
        selectedImage = PickedImageData(
          bytes: data.buffer.asUint8List(),
          name: template.id,
        );
        backgroundType = BackgroundType.image;
        fontColor = template.fontColor;
        footerColor = template.footerColor;
        blurIntensity = template.blurIntensity;
        _selectedTemplateId = template.id;
      });
    } finally {
      if (mounted) setState(() => _isApplyingTemplate = false);
    }
  }

  void _applyLayout(VerseLayoutKind kind) {
    setState(() => layout = kind);
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
    return TextStyle(
      fontSize: size,
      fontWeight: _resolvedFontWeight(),
      color: fontColor,
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
    return TextStyle(
      fontSize: size * 0.72,
      fontWeight: FontWeight.w700,
      color: fontColor,
      fontStyle: _resolvedFontStyle(),
      height: 1.2,
    );
  }

  TextStyle _highlightTextStyle({
    required _HighlightRule rule,
    required double size,
  }) {
    final hasFill = rule.fillColor != Colors.transparent;
    final baseStyle = TextStyle(
      fontSize: size * rule.sizeScale,
      color: rule.textColor,
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
    if (rule.fontFamily == _kDefaultHighlightFont) return baseStyle;
    return GoogleFonts.getFont(rule.fontFamily, textStyle: baseStyle);
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

  String _todayDateLabel() =>
      DateFormat(_dateFormatPattern).format(DateTime.now());

  /// Transparent by design — this sits on the editor panel's own frosted
  /// blur, so a solid card here would read as a hard white box on top of
  /// glass. A top divider gives the same "this is its own section" cue
  /// without covering the blur. [title] is optional: omit it when the
  /// enclosing tab's own label already says the same thing (e.g. the Edit
  /// tab), so the word doesn't render twice on screen.
  Widget _buildSectionCard({
    String? title,
    required String description,
    required Widget child,
    bool withTopDivider = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: withTopDivider ? 18 : 0),
      decoration: withTopDivider
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
          ],
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildColorSliderSection({
    required String title,
    required Color selectedColor,
    required double saturation,
    required double lightness,
    required ValueChanged<Color> onChanged,
    List<Color> quickColors = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SmoothColorSlider(
                value: selectedColor,
                saturation: saturation,
                lightness: lightness,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
              ),
            ),
          ],
        ),
        if (quickColors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: quickColors.map((color) {
              return GestureDetector(
                onTap: () => onChanged(color),
                child: _buildColorDot(
                  color: color,
                  isSelected: selectedColor == color,
                  isClear: color == Colors.transparent,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightWordSelector() {
    final tokens = _highlightableTokens();
    if (tokens.isEmpty) {
      return Text(
        context.t(
            'ui.verse_share.type_verse_text_first_then_tap_words_here_to_highlight'),
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
                  context.t('ui.verse_share.tap_any_word_to_highlight_it'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(
                'ui.verse_share.every_selected_word_gets_its_own_style_controls_below'),
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
                context.t('verse_share.highlights_empty'),
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
                context.t('ui.verse_share.selected_highlights'),
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
              label: Text(context.t('ui.verse_share.clear')),
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
                tooltip: context.t('common.delete'),
                onPressed: () => _removeHighlightRule(rule),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t('verse_share.highlight_weight'),
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
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.t('ui.verse_share.bold_425d')),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.t('ui.verse_share.normal_6dd2')),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(context.t('ui.verse_share.italic_fe26')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t(
              'verse_share.scale_value',
              parameters: {'value': rule.sizeScale.toStringAsFixed(2)},
            ),
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
          _buildColorSliderSection(
            title: context.t('verse_share.highlight_text_color'),
            selectedColor: rule.textColor,
            saturation: 0.7,
            lightness: 0.42,
            quickColors: const [Colors.black, Colors.white],
            onChanged: (color) {
              _updateHighlightRule(
                rule,
                (current) => current.copyWith(textColor: color),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildColorSliderSection(
            title: context.t('verse_share.highlight_fill_color'),
            selectedColor: rule.fillColor,
            saturation: 0.6,
            lightness: 0.75,
            quickColors: const [Colors.transparent],
            onChanged: (color) {
              _updateHighlightRule(
                rule,
                (current) => current.copyWith(fillColor: color),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildColorSliderSection(
            title: context.t('verse_share.highlight_border_color'),
            selectedColor: rule.borderColor,
            saturation: 0.7,
            lightness: 0.5,
            quickColors: const [Colors.transparent],
            onChanged: (color) {
              // A border always replaces any fill — the two looks aren't
              // meant to combine, so picking a real border color clears fill.
              _updateHighlightRule(
                rule,
                (current) => current.copyWith(
                  borderColor: color,
                  fillColor:
                      color == Colors.transparent
                          ? current.fillColor
                          : Colors.transparent,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            context.t('verse_share.highlight_font_family'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _highlightFontOptions.map((family) {
              final selected = rule.fontFamily == family;
              final label = family == _kDefaultHighlightFont
                  ? context.t('verse_share.highlight_font_default')
                  : family;
              final labelStyle = family == _kDefaultHighlightFont
                  ? const TextStyle()
                  : GoogleFonts.getFont(family);
              return ChoiceChip(
                label: Text(label, style: labelStyle),
                selected: selected,
                onSelected: (_) {
                  _updateHighlightRule(
                    rule,
                    (current) => current.copyWith(fontFamily: family),
                  );
                },
              );
            }).toList(growable: false),
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

/// Always-shown branding row: church logo, title and contact number — part
/// of "the complete image" every share card produces, AI-generated or
/// manual, so a downloaded card is self-identifying without extra editor
/// steps.
class _VerseShareBranding extends ConsumerWidget {
  const _VerseShareBranding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);
    final churchLogo = configAsync.maybeWhen(
      data: (config) => config.churchLogo.trim(),
      orElse: () => '',
    );
    final appTitle = ref.t('church_tab.app_title');
    final contact = ref.watch(selectedChurchProvider)?.contact.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BrandLogo(churchLogo: churchLogo),
          if (appTitle.isNotEmpty || contact.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (appTitle.isNotEmpty)
                    Text(
                      appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (contact.isNotEmpty)
                    Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.churchLogo});

  final String churchLogo;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(
      Icons.church_rounded,
      size: 16,
      color: Colors.white,
    );
    if (churchLogo.isEmpty) {
      return const CircleAvatar(
        radius: 14,
        backgroundColor: Colors.white24,
        child: fallback,
      );
    }
    final uri = Uri.tryParse(churchLogo);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    return ClipOval(
      child: isNetwork
          ? Image.network(
              churchLogo,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            )
          : Image.asset(
              churchLogo,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

const _kDefaultHighlightFont = 'Default';

const _highlightFontOptions = [
  _kDefaultHighlightFont,
  'Playfair Display',
  'Merriweather',
  'Poppins',
  'Pacifico',
  'Caveat',
  'Dancing Script',
];

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
    required this.sizeScale,
    this.fontFamily = _kDefaultHighlightFont,
  });

  final String id;
  final String phrase;
  final int? sourceStart;
  final int? sourceEnd;
  final VerseFontStyleOption fontStyleOption;
  final Color textColor;
  final Color fillColor;
  final Color borderColor;
  final double sizeScale;
  final String fontFamily;

  _HighlightRule copyWith({
    String? phrase,
    int? sourceStart,
    int? sourceEnd,
    VerseFontStyleOption? fontStyleOption,
    Color? textColor,
    Color? fillColor,
    Color? borderColor,
    double? sizeScale,
    String? fontFamily,
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
      sizeScale: sizeScale ?? this.sizeScale,
      fontFamily: fontFamily ?? this.fontFamily,
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

class _SmoothColorSlider extends StatelessWidget {
  const _SmoothColorSlider({
    required this.value,
    required this.saturation,
    required this.lightness,
    required this.onChanged,
  });

  final Color value;
  final double saturation;
  final double lightness;
  final ValueChanged<Color> onChanged;

  Color _colorForHue(double hue) {
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }

  void _handlePosition(double dx, double width) {
    if (width <= 0) return;
    final fraction = (dx / width).clamp(0.0, 1.0);
    onChanged(_colorForHue(fraction * 359.999));
  }

  @override
  Widget build(BuildContext context) {
    final hue = HSLColor.fromColor(value).hue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbSize = 28.0;
        final thumbLeft =
            ((hue / 360) * width - thumbSize / 2).clamp(0.0, width - thumbSize);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              _handlePosition(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _handlePosition(details.localPosition.dx, width),
          child: SizedBox(
            height: thumbSize + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: (thumbSize + 4 - 14) / 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: List.generate(
                          13,
                          (i) => _colorForHue(i * 30.0),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 60),
                  left: thumbLeft,
                  top: 0,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.fillColor, required this.borderColor});

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final notch = size.height * 0.35;
    final path = Path()
      ..moveTo(notch, 0)
      ..lineTo(size.width - notch, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(notch, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}
