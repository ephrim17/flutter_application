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

    if (activeScreen == 'quiz') {
      screenWidget = const QuizLauncher();
    } else if (activeScreen == 'dice') {
      screenWidget = const GradientContainer.standardColor();
    } else if ( activeScreen == 'expense') {
      screenWidget = const ExpenseState();
    }

    return MaterialApp(
      home: screenWidget,
    );
  }
}