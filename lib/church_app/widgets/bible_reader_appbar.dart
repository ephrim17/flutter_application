import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/bible_font_size_constant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BibleReaderAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;

  const BibleReaderAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(bibleFontSizeProvider);

    return AppBar(
      title: title,
      actions: [
        PopupMenuButton<BibleFontSize>(
          tooltip: context.t('common.font_size', fallback: 'Font size'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: const Text(
            'aA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onSelected: (value) {
            ref.read(bibleFontSizeProvider.notifier).state = value;
          },
          itemBuilder: (context) => [
            _fontItem(
              label: context.t('common.small', fallback: 'Small'),
              value: BibleFontSize.small,
              selected: fontSize == BibleFontSize.small,
            ),
            _fontItem(
              label: context.t('common.medium', fallback: 'Medium'),
              value: BibleFontSize.medium,
              selected: fontSize == BibleFontSize.medium,
            ),
            _fontItem(
              label: context.t('common.large', fallback: 'Large'),
              value: BibleFontSize.large,
              selected: fontSize == BibleFontSize.large,
            ),
          ],
        ),
        if (actions != null) ...actions!,
      ],
    );
  }

  PopupMenuItem<BibleFontSize> _fontItem({
    required String label,
    required BibleFontSize value,
    required bool selected,
  }) {
    return PopupMenuItem<BibleFontSize>(
      value: value,
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          if (selected)
            const Icon(
              Icons.check,
              size: 16,
            ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
