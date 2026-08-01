import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';

class ReadingProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final Color progressColor;

  const ReadingProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.progressColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'reading_plan.days_completed',
              parameters: {'current': '$current', 'total': '$total'},
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(
              'reading_plan.percent_completed',
              parameters: {
                'percent': (progress * 100).toStringAsFixed(0),
              },
            ),
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
