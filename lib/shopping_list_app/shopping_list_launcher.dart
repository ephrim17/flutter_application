import 'package:flutter/material.dart';
import 'package:flutter_application/shopping_list_app/widgets/grocery_list.dart';
import 'package:google_fonts/google_fonts.dart';

class ShoppingListLauncher extends StatelessWidget {
  const ShoppingListLauncher({super.key, required this.restartApp});

  final void Function(String value) restartApp;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return  GroceryList(restartApp: restartApp);
  }
}