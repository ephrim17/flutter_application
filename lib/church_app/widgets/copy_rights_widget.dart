import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/side_drawer/about_providers.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CopyrightWidget extends ConsumerWidget {
  const CopyrightWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aboutAsync = ref.watch(aboutProvider);
    final aboutTitle = aboutAsync.asData?.value?.title.trim();
    final churchName = ref.watch(selectedChurchProvider)?.name.trim();
    final resolvedTitle =
        aboutTitle != null && aboutTitle.isNotEmpty ? aboutTitle : churchName;
    final label = resolvedTitle != null && resolvedTitle.isNotEmpty
        ? '$resolvedTitle all rights reserved'
        : 'All rights reserved';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
