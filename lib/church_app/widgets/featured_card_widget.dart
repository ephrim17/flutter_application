import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';

class FeaturedCard extends StatelessWidget {
  final String badgeText;
  final String title;
  final String description;
  final String buttonText;
  final String imagePath;
  final VoidCallback onPressed;

  const FeaturedCard({
    super.key,
    required this.badgeText,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.imagePath,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Content Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Left Text Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badgeText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              /// Right Image
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                
                child: Image.asset(
                  imagePath,
                  height: 120,
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          /// CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
                onPressed: onPressed,
                child: Text(
                  buttonText,
                ),
              ),
          ),
        ],
      ),
    );
  }
}
