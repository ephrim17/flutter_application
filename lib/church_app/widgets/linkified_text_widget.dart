import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final RegExp _urlPattern = RegExp(
    r'((https?:\/\/|www\.)[^\s]+|(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/[^\s]*)?)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final defaultStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final resolvedLinkStyle = widget.linkStyle ??
        defaultStyle.copyWith(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        );

    if (!_urlPattern.hasMatch(widget.text)) {
      return Text(
        widget.text,
        style: defaultStyle,
      );
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: _buildSpans(widget.text, resolvedLinkStyle),
      ),
    );
  }

  List<InlineSpan> _buildSpans(String text, TextStyle linkStyle) {
    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final rawUrl = match.group(0)!;
      final linkText = _cleanUrl(rawUrl);
      final trailingText = rawUrl.substring(linkText.length);
      final uri = _normalizeUri(linkText);
      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(uri);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: linkText,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      if (trailingText.isNotEmpty) {
        spans.add(TextSpan(text: trailingText));
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  Uri _normalizeUri(String rawUrl) {
    final normalized = rawUrl.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return Uri.parse(normalized);
    }

    return Uri.parse('https://$normalized');
  }

  String _cleanUrl(String rawUrl) {
    return rawUrl.trim().replaceAll(RegExp(r'[),.!?;:]+$'), '');
  }

  Future<void> _openLink(Uri uri) async {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'common.open_link_failed',
              fallback: 'Unable to open link',
            ),
          ),
        ),
      );
    }
  }
}
