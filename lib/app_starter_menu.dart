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

  (Color?, Widget?, ColorScheme?) getAppColors(){

    var appDefaultColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 97, 21, 212));
    var expenseColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 213, 104, 9));
    var quizColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 40, 108, 203));

    if (activeScreen == 'Quiz App') { 
      return (quizColorScheme.primary , const QuizLauncher(), quizColorScheme);
    } else if (activeScreen == 'Dice App') { 
      return (null, const GradientContainer.standardColor(), null);
    } else if (activeScreen == 'Expense App'){
      return (expenseColorScheme.onInverseSurface, const ExpenseState(), expenseColorScheme);
    } else {
      return (appDefaultColorScheme.onInverseSurface, AppStarterScreen(selectedMenu: selectedMenu), appDefaultColorScheme);
    }
  }


  @override
  Widget build(BuildContext context) {

    var (scaffoldBgColor, screenWidget, appColorScheme) = getAppColors();

    return MaterialApp(
      theme: ThemeData().copyWith(
        scaffoldBackgroundColor: scaffoldBgColor,
        colorScheme: appColorScheme,
        appBarTheme: const AppBarTheme().copyWith(
            foregroundColor: appColorScheme?.onPrimaryContainer,
            backgroundColor: appColorScheme?.onInverseSurface
        ),
        cardTheme: const CardTheme().copyWith(
          color: appColorScheme?.inversePrimary
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: appColorScheme?.inversePrimary,
            foregroundColor: appColorScheme?.onPrimaryFixedVariant
          )
        ),
        textTheme: ThemeData().textTheme.copyWith(
          titleLarge: TextStyle(
            fontWeight: FontWeight.normal,
            color: appColorScheme?.onErrorContainer
          )
        )
      ),
      home: screenWidget,
    );
  }
}