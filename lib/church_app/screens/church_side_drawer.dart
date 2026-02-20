import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/drawer_constants.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ChurchSideDrawer extends StatelessWidget {
  const ChurchSideDrawer({super.key, required this.onSelectedMenu});

  final void Function (String menu) onSelectedMenu;

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
                "Church",
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

  final void Function (String menu) onSelectedMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final items = DrawerMenuItem.values;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          userAsync.when(
            loading: () => const DrawerHeader(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const DrawerHeader(
              child: Text('Error loading user'),
            ),
            data: (user) {
              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor
                ),
                accountName: Text(
                  user?.name ?? '',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                accountEmail: Text(user?.email ?? '', style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                )
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

          const Spacer(),

          /// 🔓 Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              // No navigation here 👇
              // AppEntry will handle it
            },
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
