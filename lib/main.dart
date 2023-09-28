import 'package:flutter/material.dart';
import 'package:flutter_application/gradient_container.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: GradientContainer.standardColor(),
      ),
    ),
  );
}
