import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/answerbutton.dart';

class AppStarterScreen extends StatelessWidget {
  AppStarterScreen({super.key, required this.selectedMenu});

  final menuItems = ['Quiz App', 'Expense App', 'Dice App'];
  final void Function(String value) selectedMenu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Apps',
          style: TextStyle(
              color: Color.fromARGB(255, 37, 6, 86),
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 225, 214, 253),
      ),
      body: ListView.builder(
        itemCount: menuItems.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: AnswerButton(
              answerText: menuItems[index], onPressed: selectedMenu),
        ),
      ),
    );
  }
}
