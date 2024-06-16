import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/question_number.dart';

class ResultSummary extends StatelessWidget {
  const ResultSummary(this.summary, {super.key});

  final List<Map<String, Object>> summary;

  String yourAnswer(text){
    var yourAnswer = 'Your Answer is '+ text;
    return yourAnswer;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: SingleChildScrollView(
        child: Column(
          children: summary.map(
            (item) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionNumber(((item['question_index'] as int)), item),
                  const SizedBox(height: 20,),
                  Expanded(
                    child: Column(
                      children: [
                        Text(item['question'] as String ,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          'Your Answer is: ${item['user_answer']}',
                          style: const TextStyle(
                              color: Color.fromARGB(255, 240, 183, 252), fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Correct Answer is: ${item['correct_answer']}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900), 
                        ),
                        const SizedBox(height: 20,)
                      ],
                    ),
                  )
                ],
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}
