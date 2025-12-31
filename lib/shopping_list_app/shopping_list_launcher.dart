import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShoppingListLauncher extends StatelessWidget {
  const ShoppingListLauncher({super.key, required this.restartApp});

  final void Function(String value) restartApp;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        actions: [
          IconButton(onPressed: () =>restartApp('app-start-screen'), icon: const Icon(Icons.home)),
          IconButton(onPressed: (){}, icon: const Icon(Icons.add_shopping_cart)),
        ],
        title: Text(
          "Shopping List",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: Center(
        child: Text(
          "this is the Shopping List App Launcher Screen",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      )
    );
  }
}