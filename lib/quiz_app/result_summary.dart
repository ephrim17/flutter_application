import 'package:flutter/material.dart';

class ResultSummary extends StatelessWidget {
  const ResultSummary(this.summary, {super.key});

  final List<Map<String, Object>> summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: summary.map(
        (item) {
          return Row(
            children: [
              Text(((item['question_index'] as int) + 1).toString()),
              Column(
                children: [
                  Text(
                    item['question'] as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    item['user_answer'] as String,
                    style: const TextStyle(
                        color: Color.fromARGB(255, 240, 183, 252)),
                  ),
                  Text(
                    item['correct_answer'] as String,
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              )
            ],
          );
        },
      ).toList(),
    );
  }
}
