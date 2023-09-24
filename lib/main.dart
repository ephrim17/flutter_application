import 'package:flutter/material.dart';
import 'package:flutter_application/gradient_container.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: GradientContainer(
          colors: [
            Color.fromARGB(255, 0, 0, 0),
            Color.fromARGB(255, 31, 2, 71)
          ],
        ),
      ),
    ),
  );
}
