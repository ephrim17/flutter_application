import 'package:flutter/material.dart';

class CopyrightWidget extends StatelessWidget {
  const CopyrightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        '© 2026 Your Church Name. All rights reserved.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
