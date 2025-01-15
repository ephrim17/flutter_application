import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Mealcategories extends StatelessWidget {
  const Mealcategories({super.key});

  @override
  Widget build(BuildContext context) {
    return  
    Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          "Meal App",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: GridView(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10
      ), children: [
        Text("1", style: Theme.of(context).textTheme.bodyMedium),
        Text("2", style: Theme.of(context).textTheme.bodyMedium),
        Text("3", style: Theme.of(context).textTheme.bodyMedium),
        Text("4", style: Theme.of(context).textTheme.bodyMedium),
        Text("5", style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
    );
    
  }
}