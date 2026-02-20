import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/shimmer_image.dart';

class DetailWidget extends StatefulWidget {
  const DetailWidget({super.key, required this.title, required this.description, this.imageUrl});

  final String title;
  final String description;
  final String? imageUrl;

  @override
  State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: AppBarTitle(text: widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Image (same 16:9 landscape)
            if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ShimmerImage(
                      imageUrl: widget.imageUrl!,
                    ),
                  ),
                ),

            const SizedBox(height: 8.0),

            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: carouselBoxDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}