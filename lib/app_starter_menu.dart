import 'package:flutter/material.dart';
import 'package:flutter_application/app_starter_screen.dart';
import 'package:flutter_application/dice_app/gradient_container.dart';
import 'package:flutter_application/expense_app/expense_state.dart';
import 'package:flutter_application/quiz_app/quiz_launcher.dart';

class AppStarterMenu extends StatefulWidget {
  const AppStarterMenu({super.key});

  @override
  State<AppStarterMenu> createState() => _AppStarterMenuState();
}

class _AppStarterMenuState extends State<AppStarterMenu> {

  var activeScreen = "app-start-screen";

  void selectedMenu(screen) {
    setState(() {
      activeScreen = screen;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget screenWidget = AppStarterScreen(selectedMenu: selectedMenu);
    Color scaffoldBgColor = const Color.fromARGB(255, 225, 214, 253);

    if (activeScreen == 'Quiz App') {
      screenWidget = const QuizLauncher();
      scaffoldBgColor = Colors.deepPurple;
    } else if (activeScreen == 'Dice App') {
      screenWidget = const GradientContainer.standardColor();
    } else if ( activeScreen == 'Expense App') {
      screenWidget = const ExpenseState();
      scaffoldBgColor = const Color.fromARGB(255, 250, 246, 232);
    }

    return MaterialApp(
      theme: ThemeData().copyWith(
      scaffoldBackgroundColor: scaffoldBgColor),
      home: screenWidget,
    );
  }
}