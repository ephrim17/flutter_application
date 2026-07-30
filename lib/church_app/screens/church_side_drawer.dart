import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_count_badge.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/drawer_constants.dart';
import 'package:flutter_application/church_app/models/side_drawer_models/prayer_request_model.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/favorites_provider.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/prayer_providers.dart';
import 'package:flutter_application/church_app/screens/side_drawer/equipment_viewmodel.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/widgets/member_since_chip_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChurchSideDrawer extends StatelessWidget {
  const ChurchSideDrawer({super.key, required this.onSelectedMenu});

  final void Function(String menu) onSelectedMenu;

  @override
  Widget build(BuildContext context) {
    final items = DrawerMenuItem.values;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.t('drawer.title', fallback: 'Church'),
                style: TextStyle(
                  color: Theme.of(context).primaryColorDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ...items.map(
            (item) => ListTile(
              leading: Icon(
                item.icon,
              ),
              title: Text(item.label),
              onTap: () => _handleTap(context, item),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, DrawerMenuItem item) {
    Navigator.pop(context);

    if (item.route != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => item.route!,
      ));
    }
  }
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, required this.onSelectedMenu});

  final void Function(String menu) onSelectedMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final config = ref.watch(appConfigProvider).asData?.value;
    final canAccessFinanceDashboard = ref.watch(financeDashboardAccessProvider);
    final items = DrawerMenuItem.values.where((item) {
      if (config != null && !item.isEnabledBy(config)) {
        return false;
      }
      if (item == DrawerMenuItem.financialDashboard) {
        return canAccessFinanceDashboard;
      }
      return isAdmin || !item.adminOnly;
    }).toList();
    final churchId =
        ref.watch(currentChurchIdProvider).asData?.value?.trim() ?? '';
    final favoritesCount = ref.watch(favoritesProvider).asData?.value.length;
    final myPrayersAsync = ref.watch(myPrayerRequestsProvider);
    final globalPrayersAsync = ref.watch(globalPrayerRequestsProvider);
    final allPrayersAsync =
        isAdmin ? ref.watch(allPrayerRequestsProvider) : null;
    final prayerCount = _overallPrayerCount(
      churchId: churchId,
      localPrayers: isAdmin
          ? allPrayersAsync?.asData?.value
          : myPrayersAsync.asData?.value,
      globalPrayers: globalPrayersAsync.asData?.value,
    );
    final membersCount = items.contains(DrawerMenuItem.members)
        ? ref.watch(membersProvider).asData?.value.length
        : null;
    final equipmentCount = items.contains(DrawerMenuItem.equipment)
        ? ref.watch(equipmentItemsProvider).asData?.value.length
        : null;
    final badgeCounts = <DrawerMenuItem, int?>{
      DrawerMenuItem.favorites: favoritesCount,
      DrawerMenuItem.prayerRequest: prayerCount,
      DrawerMenuItem.members: membersCount,
      DrawerMenuItem.equipment: equipmentCount,
    };

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          userAsync.when(
            loading: () => const DrawerHeader(
              child: Center(child: AppLoadingIndicator()),
            ),
            error: (_, __) => DrawerHeader(
              child: Text(
                context.t(
                  'drawer.error_loading_user',
                  fallback: 'Error loading user',
                ),
              ),
            ),
            data: (user) {
              final theme = Theme.of(context);
              return DrawerHeader(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                ),
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? '',
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    MemberSinceChip(date: user?.createdAt),
                  ],
                ),
              );
            },
          ),

          /// 🧭 Menu items
          ...items.map(
            (item) => ListTile(
              leading: Icon(
                item.icon,
              ),
              title: Text(item.label),
              trailing: badgeCounts[item] == null
                  ? null
                  : AppCountBadge(
                      count: badgeCounts[item]!,
                      semanticLabel: item.label,
                    ),
              onTap: () => _handleTap(context, item),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, DrawerMenuItem item) {
    Navigator.pop(context);

    if (item.route != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => item.route!,
      ));
    }
  }
}

int? _overallPrayerCount({
  required String churchId,
  required List<PrayerRequest>? localPrayers,
  required List<PrayerRequest>? globalPrayers,
}) {
  if (localPrayers == null || globalPrayers == null) return null;

  final requestKeys = <String>{
    for (final prayer in localPrayers) 'local:${prayer.id}',
  };
  for (final prayer in globalPrayers) {
    final isLinkedLocalPrayer = churchId.isNotEmpty &&
        prayer.sourceChurchId == churchId &&
        prayer.sourcePrayerId.isNotEmpty;
    requestKeys.add(
      isLinkedLocalPrayer
          ? 'local:${prayer.sourcePrayerId}'
          : 'global:${prayer.id}',
    );
  }
  return requestKeys.length;
}
