import 'package:flutter/material.dart';

class StyledText extends StatelessWidget {
  const StyledText({super.key, required this.outputText});

  final String outputText;

  @override
  Widget build(context) {
    return Center(
        child: Text(outputText,
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
      );
  }
}