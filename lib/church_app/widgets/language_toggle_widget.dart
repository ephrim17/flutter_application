import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

enum BibleLanguage { tamil, english }

class BibleLanguageToggle extends ConsumerWidget {
  final StateProvider<BibleLanguage> provider;

  const BibleLanguageToggle({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(provider);
    final isEnglish = lang == BibleLanguage.english;

    return GestureDetector(
      onTap: () {
        ref.read(provider.notifier).state =
            isEnglish ? BibleLanguage.tamil : BibleLanguage.english;
      },
      child: Container(
        width: 60,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              isEnglish ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isEnglish ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(cornerRadius),
            ),
            child: Text(
              isEnglish ? 'EN' : 'TN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
