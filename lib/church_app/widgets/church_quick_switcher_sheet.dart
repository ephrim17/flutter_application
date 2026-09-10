import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider, churchByIdProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Quick church switcher — just the churches this person is already an
/// approved member of, tap to switch straight away. Deliberately not the
/// full `SelectChurchScreen` (Your churches/Other churches + request-access
/// + global feed): that screen is for discovering/joining a NEW church,
/// reachable instead from Settings — this sheet is only for hopping between
/// churches already joined.
///
/// Pops with the picked [Church], or null if dismissed without picking;
/// the caller (`ChurchTabScreen`) performs the actual switch, since by the
/// time this sheet's own context finishes popping it may no longer be safe
/// to navigate from.
class ChurchQuickSwitcherSheet extends ConsumerWidget {
  const ChurchQuickSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipsAsync = ref.watch(myMembershipsProvider);
    final currentChurchId = ref.watch(selectedChurchProvider)?.id;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('church.switcher_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            membershipsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: AppLoadingIndicator()),
              ),
              error: (_, __) => Text(context.t('church.directory_load_error')),
              data: (memberships) {
                final approvedChurchIds = memberships
                    .where((membership) => membership.approved)
                    .map((membership) => membership.churchId)
                    .toList(growable: false);

                if (approvedChurchIds.isEmpty) {
                  return Text(context.t('church.switcher_empty'));
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: approvedChurchIds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final churchId = approvedChurchIds[index];
                      final churchAsync =
                          ref.watch(churchByIdProvider(churchId));
                      final church = churchAsync.value;
                      final isCurrent = churchId == currentChurchId;

                      if (church == null) return const SizedBox.shrink();

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ChurchLogoAvatar(logo: church.logo, size: 42),
                        title: Text(
                          church.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: isCurrent
                            ? null
                            : () => Navigator.of(context).pop(church),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
