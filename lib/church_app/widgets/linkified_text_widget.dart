import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/feed_link_utils.dart';
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

    if (!FeedLinkUtils.hasLinks(widget.text)) {
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

    for (final match in FeedLinkUtils.linkMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openLink(match.uri);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: match.linkText,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      if (match.trailingText.isNotEmpty) {
        spans.add(TextSpan(text: match.trailingText));
      }

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
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
