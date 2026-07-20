import 'package:flutter/material.dart';

class AppBarTitle extends StatelessWidget {
  const AppBarTitle({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.appBarTheme.titleTextStyle ??
          theme.textTheme.titleSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}
