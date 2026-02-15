import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key, required this.text, required this.padding
  });

  final String text;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: padding),
      child: Text(text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          )
        ),
    );
  }
}