import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/bible_font_size_constant.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';
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
        AppPopupMenu<BibleFontSize>(
          tooltip: context.t('common.font_size', fallback: 'Font size'),
          minWidth: 190,
          trigger: const Text(
            'aA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onSelected: (value) {
            ref.read(bibleFontSizeProvider.notifier).state = value;
          },
          actions: [
            AppPopupMenuAction(
              label: context.t('common.small', fallback: 'Small'),
              value: BibleFontSize.small,
              icon: Icons.text_decrease_rounded,
              selected: fontSize == BibleFontSize.small,
            ),
            AppPopupMenuAction(
              label: context.t('common.medium', fallback: 'Medium'),
              value: BibleFontSize.medium,
              icon: Icons.text_fields_rounded,
              selected: fontSize == BibleFontSize.medium,
            ),
            AppPopupMenuAction(
              label: context.t('common.large', fallback: 'Large'),
              value: BibleFontSize.large,
              icon: Icons.text_increase_rounded,
              selected: fontSize == BibleFontSize.large,
            ),
          ],
        ),
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
