import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

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