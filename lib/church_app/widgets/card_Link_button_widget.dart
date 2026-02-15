import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class CardLinkButtonWidget extends StatelessWidget {
  final String title;
  final String buttonText;
  final Icon iconStyle;
  final VoidCallback onPressed;
  final Gradient? gradient;

  const CardLinkButtonWidget({
    super.key,
    required this.title,
    required this.buttonText,
    required this.iconStyle,
    required this.onPressed,
    this.gradient,
  });

  @override
  @override
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(24),
    decoration: carouselBoxDecoration(context),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconStyle,
        const SizedBox(width: 16),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 👈 important
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Title
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              /// Button aligned right
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onPressed,
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
