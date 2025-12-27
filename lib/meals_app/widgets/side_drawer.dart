import 'package:flutter/material.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({super.key, required this.onSelectedMenu});

  final void Function (String menu) onSelectedMenu;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColorLight,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Meals App",
                style: TextStyle(
                  color: Theme.of(context).primaryColorDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant),
            title: const Text("Meals"),
            onTap: () => onSelectedMenu('meal'),
          ),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text("Filters"),
            onTap: () => onSelectedMenu('filter'),
          ),
        ],
      ),
    );
  }
}