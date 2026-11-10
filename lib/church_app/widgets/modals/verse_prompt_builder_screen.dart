import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/verse_poster_prompt.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the poster prompt builder for one verse.
///
/// The app no longer renders AI images itself: this assembles a prompt the
/// person copies and pastes into ChatGPT or Gemini, so the image (and its
/// cost) lives in their own account. [isGuestShare] keeps the church's name
/// and contact out of the prefilled top line and footer, as the manual
/// editor does for the guest shell.
Future<void> showVersePromptBuilder(
  BuildContext context, {
  required String text,
  required String reference,
  bool isGuestShare = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VersePromptBuilderScreen(
        text: text,
        reference: reference,
        isGuestShare: isGuestShare,
      ),
    ),
  );
}

final _tamilScript = RegExp(r'[஀-௿]');

class VersePromptBuilderScreen extends ConsumerStatefulWidget {
  const VersePromptBuilderScreen({
    super.key,
    required this.text,
    required this.reference,
    this.isGuestShare = false,
  });

  final String text;
  final String reference;
  final bool isGuestShare;

  @override
  ConsumerState<VersePromptBuilderScreen> createState() =>
      _VersePromptBuilderScreenState();
}

class _VersePromptBuilderScreenState
    extends ConsumerState<VersePromptBuilderScreen> {
  final _topName = TextEditingController();
  final _title = TextEditingController();
  final _verse = TextEditingController();
  final _reference = TextEditingController();
  final _background = TextEditingController();
  final _ministry = TextEditingController();
  final _contact = TextEditingController();

  // Dropdowns only take an initial value, so Reset rebuilds them under a new
  // key to show the restored defaults.
  int _resetCount = 0;

  int _topStyle = 0;
  bool _useDate = false;
  DateTime _date = DateTime.now();
  VersePosterDateFormat _dateFormat = VersePosterDateFormat.long;
  int _datePlacement = 0;
  bool _useTitle = false;
  int _titleStyle = 0;
  String _verseSize = 'Large';
  int _versePosition = 0;
  String _language = versePosterEnglishLanguage;
  int _textStyle = 0;
  int _referenceStyle = 0;
  int _theme = 0;
  int _renderStyle = 0;
  int _ratio = 0;
  int _mood = 0;
  bool _useFooter = false;
  bool _useLogo = false;
  int _footerStyle = 0;

  @override
  void initState() {
    super.initState();
    _applyDefaults();
    for (final controller in _controllers) {
      controller.addListener(_onTextChanged);
    }
  }

  List<TextEditingController> get _controllers => [
        _topName,
        _title,
        _verse,
        _reference,
        _background,
        _ministry,
        _contact,
      ];

  void _onTextChanged() => setState(() {});

  /// Prefills from the verse and the selected church, so the common case —
  /// today's verse, branded for this church — is one tap on Copy.
  void _applyDefaults() {
    final church =
        widget.isGuestShare ? null : ref.read(selectedChurchProvider);
    final churchName = church?.name.trim() ?? '';
    final contact = church?.contact.trim() ?? '';

    _topName.text = churchName;
    _title.text = '';
    _verse.text = widget.text;
    _reference.text = widget.reference;
    _background.text = versePosterDefaultBackground;
    _ministry.text = churchName;
    _contact.text = contact;

    _topStyle = 0;
    _useDate = false;
    _date = DateTime.now();
    _dateFormat = VersePosterDateFormat.long;
    _datePlacement = 0;
    _useTitle = false;
    _titleStyle = 0;
    _verseSize = 'Large';
    _versePosition = 0;
    _language = _tamilScript.hasMatch(widget.text)
        ? versePosterTamilLanguage
        : versePosterEnglishLanguage;
    _textStyle = 0;
    _referenceStyle = 0;
    _theme = 0;
    _renderStyle = 0;
    _ratio = 0;
    _mood = 0;
    _useFooter = churchName.isNotEmpty || contact.isNotEmpty;
    _useLogo = false;
    _footerStyle = 0;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _prompt => buildVersePosterPrompt(
        VersePosterPromptOptions(
          verseText: _verse.text,
          reference: _reference.text,
          topName: _topName.text,
          topStyle: _topStyle,
          useDate: _useDate,
          dateText: formatVersePosterDate(_date, _dateFormat),
          datePlacement: _datePlacement,
          useTitle: _useTitle,
          title: _title.text,
          titleStyle: _titleStyle,
          verseSize: _verseSize,
          versePosition: _versePosition,
          language: _language,
          textStyle: _textStyle,
          referenceStyle: _referenceStyle,
          background: _background.text,
          theme: _theme,
          renderStyle: _renderStyle,
          ratio: _ratio,
          mood: _mood,
          useFooter: _useFooter,
          ministry: _ministry.text,
          contact: _contact.text,
          useLogo: _useLogo,
          footerStyle: _footerStyle,
        ),
      );

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.t('ui.verse_prompt.copied'))),
      );
  }

  void _reset() {
    setState(() {
      _applyDefaults();
      _resetCount++;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verseSizeLabels = {
      'Small': context.t('ui.verse_prompt.size_small'),
      'Medium': context.t('ui.verse_prompt.size_medium'),
      'Large': context.t('ui.verse_prompt.size_large'),
      'Extra Large': context.t('ui.verse_prompt.size_extra_large'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ui.verse_prompt.title')),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(context.t('ui.verse_prompt.reset')),
          ),
        ],
      ),
      body: ListView(
        key: ValueKey(_resetCount),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            context.t('ui.verse_prompt.intro'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_top'),
            children: [
              AppTextField(
                controller: _topName,
                label: context.t('ui.verse_prompt.top_name'),
              ),
              _choice(
                label: context.t('ui.verse_prompt.style'),
                options: versePosterTopStyles,
                value: _topStyle,
                onChanged: (v) => _topStyle = v,
              ),
              _toggle(
                label: context.t('ui.verse_prompt.add_date'),
                value: _useDate,
                onChanged: (v) => _useDate = v,
              ),
              if (_useDate) ...[
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(formatVersePosterDate(_date, _dateFormat)),
                ),
                AppDropdownField<VersePosterDateFormat>(
                  initialValue: _dateFormat,
                  labelText: context.t('ui.verse_prompt.date_format'),
                  items: [
                    for (final format in VersePosterDateFormat.values)
                      DropdownMenuItem(
                        value: format,
                        child: Text(
                          formatVersePosterDate(_date, format),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _dateFormat = v);
                  },
                ),
                _choice(
                  label: context.t('ui.verse_prompt.date_place'),
                  options: versePosterDatePlacements,
                  value: _datePlacement,
                  onChanged: (v) => _datePlacement = v,
                ),
              ],
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_verse'),
            children: [
              _toggle(
                label: context.t('ui.verse_prompt.add_title'),
                value: _useTitle,
                onChanged: (v) => _useTitle = v,
              ),
              if (_useTitle) ...[
                AppTextField(
                  controller: _title,
                  label: context.t('ui.verse_prompt.title_text'),
                  hintText: context.t('ui.verse_prompt.title_hint'),
                ),
                _choice(
                  label: context.t('ui.verse_prompt.title_style'),
                  options: versePosterTitleStyles,
                  value: _titleStyle,
                  onChanged: (v) => _titleStyle = v,
                ),
              ],
              AppTextField(
                controller: _verse,
                label: context.t('ui.verse_prompt.verse_text'),
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
              ),
              AppTextField(
                controller: _reference,
                label: context.t('ui.verse_prompt.reference'),
              ),
              AppDropdownField<String>(
                initialValue: _verseSize,
                labelText: context.t('ui.verse_prompt.verse_size'),
                items: [
                  for (final size in versePosterVerseSizes.keys)
                    DropdownMenuItem(
                      value: size,
                      child: Text(verseSizeLabels[size] ?? size),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _verseSize = v);
                },
              ),
              _choice(
                label: context.t('ui.verse_prompt.verse_position'),
                options: versePosterVersePositions,
                value: _versePosition,
                onChanged: (v) => _versePosition = v,
              ),
              AppDropdownField<String>(
                initialValue: _language,
                labelText: context.t('ui.verse_prompt.language'),
                items: [
                  for (final language in versePosterLanguages.keys)
                    DropdownMenuItem(value: language, child: Text(language)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _language = v);
                },
              ),
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_text_style'),
            children: [
              _choice(
                label: context.t('ui.verse_prompt.text_style'),
                options: versePosterTextStyles,
                value: _textStyle,
                onChanged: (v) => _textStyle = v,
              ),
              _choice(
                label: context.t('ui.verse_prompt.reference_style'),
                options: versePosterReferenceStyles,
                value: _referenceStyle,
                onChanged: (v) => _referenceStyle = v,
              ),
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_background'),
            children: [
              AppTextField(
                controller: _background,
                label: context.t('ui.verse_prompt.background'),
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
              ),
              _choice(
                label: context.t('ui.verse_prompt.theme'),
                options: versePosterThemes,
                value: _theme,
                onChanged: (v) => _theme = v,
              ),
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_render'),
            children: [
              _choice(
                label: context.t('ui.verse_prompt.render'),
                options: versePosterRenderStyles,
                value: _renderStyle,
                onChanged: (v) => _renderStyle = v,
              ),
              _choice(
                label: context.t('ui.verse_prompt.ratio'),
                options: versePosterRatios,
                value: _ratio,
                onChanged: (v) => _ratio = v,
              ),
              _choice(
                label: context.t('ui.verse_prompt.mood'),
                options: versePosterMoods,
                value: _mood,
                onChanged: (v) => _mood = v,
              ),
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_footer'),
            children: [
              _toggle(
                label: context.t('ui.verse_prompt.use_footer'),
                value: _useFooter,
                onChanged: (v) => _useFooter = v,
              ),
              if (_useFooter) ...[
                AppTextField(
                  controller: _ministry,
                  label: context.t('ui.verse_prompt.ministry'),
                ),
                AppTextField(
                  controller: _contact,
                  label: context.t('ui.verse_prompt.contact'),
                  hintText: context.t('ui.verse_prompt.contact_hint'),
                ),
                _toggle(
                  label: context.t('ui.verse_prompt.use_logo'),
                  value: _useLogo,
                  onChanged: (v) => _useLogo = v,
                ),
                _choice(
                  label: context.t('ui.verse_prompt.footer_style'),
                  options: versePosterFooterStyles,
                  value: _footerStyle,
                  onChanged: (v) => _footerStyle = v,
                ),
              ],
            ],
          ),
          _Section(
            title: context.t('ui.verse_prompt.section_prompt'),
            children: [
              Text(
                context.t('ui.verse_prompt.prompt_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: SelectableText(
                  _prompt,
                  key: const ValueKey('verse-prompt-output'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy_rounded),
            label: Text(context.t('ui.verse_prompt.copy')),
          ),
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required List<String> options,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return AppDropdownField<int>(
      initialValue: value,
      labelText: label,
      items: [
        for (var i = 0; i < options.length; i++)
          DropdownMenuItem(
            value: i,
            child: Text(options[i], overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          for (final child in children) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
