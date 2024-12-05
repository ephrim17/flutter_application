import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/answerbutton.dart';

class AppStarterScreen extends StatelessWidget {
  AppStarterScreen({super.key, required this.selectedMenu});

  final menuItems = ['quiz', 'expense', 'dice'];
  final void Function(String value) selectedMenu;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          body: Container(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: ListView.builder(
                itemCount: menuItems.length,
                itemBuilder: (context, index) => AnswerButton(
                    answerText: menuItems[index], onPressed: selectedMenu),
              ))),
    );
  }
}
