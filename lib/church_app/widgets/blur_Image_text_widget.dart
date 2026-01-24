

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class BlurImageTextContainer extends StatelessWidget {
  const BlurImageTextContainer(this.imageUrl, this.title, this.description, this.color, this.typeLabel, {super.key});
  //final Event event;

  final String imageUrl;
  final String title;
  final String description;
  final Color color;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🔹 Background Image (LOCAL)
            Image.asset(
              imageUrl,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // 🔹 Bottom gradient overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.09),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // 🔹 Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 🔹 Description
                    Text(
                      description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
