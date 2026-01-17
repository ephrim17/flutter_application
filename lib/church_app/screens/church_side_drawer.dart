import 'package:flutter/material.dart';

class ChurchSideDrawer extends StatelessWidget {
  const ChurchSideDrawer({super.key, required this.onSelectedMenu});

  final void Function (String menu) onSelectedMenu;

  @override
  Widget build(BuildContext context) {
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
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text("All Events"),
            onTap: () => onSelectedMenu('event'),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety_sharp),
            title: const Text("Prayer Requests"),
            onTap: () => onSelectedMenu('prayer'),
          ),
        ],
      ),
    );
  }
}