import 'package:flutter/material.dart';
import 'package:flutter_application/app_starter_screen.dart';
import 'package:flutter_application/dice_app/dice_launcher.dart';
import 'package:flutter_application/dice_app/gradient_container.dart';
import 'package:flutter_application/expense_app/expense_launcher.dart';
import 'package:flutter_application/meals_app/screens/meals_launcher.dart';
import 'package:flutter_application/quiz_app/quiz_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

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

  (Color?, Color?, Widget?, ColorScheme?, ColorScheme?) getAppColors(){

    var appDefaultColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 97, 21, 212));
    var appDefaultDarkColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 18, 1, 44));
    
    var expenseColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 213, 104, 9));
    var expenseDarkColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 45, 21, 0));

    var quizColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 40, 108, 203));
    var quizDarkColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 26, 63));

    var mealsColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 40, 108, 203));
    var mealsDarkColorScheme = ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 26, 63));

    if (activeScreen == 'Quiz App') { 
      return (quizColorScheme.primary , quizDarkColorScheme.onPrimaryContainer,  const QuizLauncher(), quizColorScheme, quizDarkColorScheme);
    } else if (activeScreen == 'Dice App') { 
      return (null, null, const DiceLauncher(), null, null);
    } else if (activeScreen == 'Expense App'){
      return (expenseColorScheme.onInverseSurface, expenseDarkColorScheme.onPrimaryContainer, const ExpenseLauncher(), expenseColorScheme, expenseDarkColorScheme);
    } else if (activeScreen == "Meals App") {
      return (mealsColorScheme.onInverseSurface , mealsColorScheme.onPrimaryContainer,  const MealsLauncher(), mealsColorScheme, mealsDarkColorScheme);
    } else {
      return (appDefaultColorScheme.onInverseSurface, appDefaultDarkColorScheme.onPrimaryContainer, AppStarterScreen(selectedMenu: selectedMenu), appDefaultColorScheme, appDefaultDarkColorScheme);
    }
  }


  @override
  Widget build(BuildContext context) {

    var (scaffoldBgColor, scaffoldBgDarkColor, screenWidget, appColorScheme, appColorSchemeDark) = getAppColors();

    return MaterialApp(
      darkTheme: ThemeData().copyWith(
        scaffoldBackgroundColor: scaffoldBgDarkColor,
        colorScheme: appColorSchemeDark,
        appBarTheme: const AppBarTheme().copyWith(
            foregroundColor: appColorSchemeDark?.secondaryFixed,
            backgroundColor: appColorSchemeDark?.onPrimaryFixed
        ),
        cardTheme: const CardThemeData().copyWith(
          color: appColorSchemeDark?.secondaryFixedDim,
          margin: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 15
          ),
        ),
        textTheme: ThemeData().textTheme.copyWith(
          titleLarge: TextStyle(
            fontWeight: FontWeight.normal,
            color: appColorSchemeDark?.secondaryFixed
          ),
          bodyMedium:  GoogleFonts.aBeeZee(color: appColorSchemeDark?.onPrimaryFixedVariant, fontSize: 16),
          bodySmall:  GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color)
          //can also set for each font type --> GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color)
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: appColorSchemeDark?.secondaryFixed,
            foregroundColor: appColorSchemeDark?.onPrimaryFixed
          )
        ),
      ),
      theme: ThemeData().copyWith(
        scaffoldBackgroundColor: scaffoldBgColor,
        colorScheme: appColorScheme,
        appBarTheme: const AppBarTheme().copyWith(
            foregroundColor: appColorScheme?.onPrimaryContainer,
            backgroundColor: appColorScheme?.onInverseSurface
        ),
        cardTheme:  CardThemeData().copyWith(
          color: appColorScheme?.inversePrimary,
          margin: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 15
          ),
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
          ),
          bodyMedium:  GoogleFonts.aBeeZee(color: Theme.of(context).secondaryHeaderColor),
        )
      ),
      home: screenWidget,
    );
  }
}