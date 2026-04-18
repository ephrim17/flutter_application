import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/drawer_constants.dart';
import 'package:flutter_application/church_app/providers/authentication/admin_provider.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
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
      child: Column(
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

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          userAsync.when(
            loading: () => const DrawerHeader(
              child: Center(child: CircularProgressIndicator()),
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
