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
    this.onHashtagTap,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final ValueChanged<String>? onHashtagTap;

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

    if (!FeedLinkUtils.hasLinks(widget.text) && !_hasHashtags(widget.text)) {
      return Text(
        widget.text,
        style: defaultStyle,
      );
    }

    final hashtagStyle = resolvedLinkStyle.copyWith(
      decoration: TextDecoration.none,
    );

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: _buildSpans(widget.text, resolvedLinkStyle, hashtagStyle),
      ),
    );
  }

  List<InlineSpan> _buildSpans(
    String text,
    TextStyle linkStyle,
    TextStyle hashtagStyle,
  ) {
    final spans = <InlineSpan>[];
    var start = 0;
    final matches = _inlineMatches(text);

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          switch (match) {
            case _UrlInlineMatch(:final uri):
              _openLink(uri);
            case _HashtagInlineMatch(:final tag):
              widget.onHashtagTap?.call(tag);
          }
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: match.text,
          style: switch (match) {
            _UrlInlineMatch() => linkStyle,
            _HashtagInlineMatch() => hashtagStyle,
          },
          recognizer: recognizer,
        ),
      );

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

  List<_InlineMatch> _inlineMatches(String text) {
    final matches = <_InlineMatch>[
      for (final match in FeedLinkUtils.linkMatches(text))
        _UrlInlineMatch(
          start: match.start,
          end: match.start + match.linkText.length,
          text: match.linkText,
          uri: match.uri,
        ),
      for (final match in _hashtagPattern.allMatches(text))
        _HashtagInlineMatch(
          start: match.start + ((match.group(0) ?? '').startsWith('#') ? 0 : 1),
          end: match.end,
          text: '#${match.group(1) ?? ''}',
          tag: (match.group(1) ?? '').toLowerCase(),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final filtered = <_InlineMatch>[];
    var lastEnd = -1;
    for (final match in matches) {
      if (match.start < lastEnd) continue;
      filtered.add(match);
      lastEnd = match.end;
    }
    return filtered;
  }

  bool _hasHashtags(String text) => _hashtagPattern.hasMatch(text);
}

sealed class _InlineMatch {
  const _InlineMatch({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

class _UrlInlineMatch extends _InlineMatch {
  const _UrlInlineMatch({
    required super.start,
    required super.end,
    required super.text,
    required this.uri,
  });

  final Uri uri;
}

class _HashtagInlineMatch extends _InlineMatch {
  const _HashtagInlineMatch({
    required super.start,
    required super.end,
    required super.text,
    required this.tag,
  });

  final String tag;
}

final RegExp _hashtagPattern = RegExp(
  r'(?:^|\s)#([\p{L}\p{M}\p{N}_]+)',
  unicode: true,
);
