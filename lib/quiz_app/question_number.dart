import 'package:flutter/material.dart';

class QuestionNumber extends StatelessWidget {
  
  const QuestionNumber(this.questionIndex, this.itemData,{super.key,
    //required this.isCorrectAnswer,
    //required this.questionIndex,
  });

  final Map<String, Object> itemData;
  final int questionIndex;
  //final bool isCorrectAnswer;

  @override
  Widget build(BuildContext context) {
    final questionNumber = questionIndex + 1;
    final isCorrectAnswer = itemData['user_answer'] == itemData['correct_answer'];
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:  isCorrectAnswer ? const Color.fromARGB(255, 150, 255, 131): const Color.fromARGB(255, 250, 133, 117),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        questionNumber.toString(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 22, 2, 56),
        ),
      ),
    );
  }
}