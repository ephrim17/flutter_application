import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_chart.dart';
import 'package:flutter_application/expense_app/expense_list.dart';
import 'package:flutter_application/expense_app/new_expense.dart';
import 'package:google_fonts/google_fonts.dart';

import 'expense_model.dart';

class ExpenseLauncher extends StatefulWidget {
  const ExpenseLauncher({super.key});

  @override
  State<ExpenseLauncher> createState() => _ExpenseLauncherState();
}

class _ExpenseLauncherState extends State<ExpenseLauncher> {

  final List<Expense> mockExpenses = [
   Expense(title: "Flutter", amount: 250, date: DateTime.now(), type: ExpenseCategory.work),
  //  Expense(title: "Flutter 2", amount: 350, date: DateTime.now(), type: ExpenseCategory.leisure)
  ];

  

  void addExpenseOverlay(){
      showModalBottomSheet(
        isScrollControlled: true,
        context: context, 
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) {
          return NewExpense(addExpense: addExpenses);
      });
  }

  void addExpenses(Expense expense){
    setState(() {
      mockExpenses.add(expense);
    });
  }

  void removeExpense(Expense expense){
    final expenseIndex = mockExpenses.indexOf(expense);
    setState(() {
      mockExpenses.remove(expense);
    });
    //Undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
      duration: const Duration(seconds: 5),
      content: const Text('Expense deleted'),
      action: SnackBarAction(label: 'undo', onPressed: () {
        setState(() { 
          mockExpenses.insert(expenseIndex, expense);
        });
      }),
    ));
  }

  Widget compactMode(Widget main, List<Expense> mockExpenses) {
    return Column(
      children: [
        Chart(expenses: mockExpenses),
        Expanded(child: main),
      ],
    );
  }

  Widget regularMode(Widget main, List<Expense> mockExpenses) {
    return Row(
      children: [
        Expanded(child: Chart(expenses: mockExpenses)),
        Expanded(child: main),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    //final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    //use this isDarkMode and optimise conditions accordingly. 

    final width = MediaQuery.of(context).size.width;
    
    Widget main = const Center(child: Text('No Expenses Found..Please add some'),);

    if (mockExpenses.isNotEmpty) {
        main = ExpenseList(expenses: mockExpenses, removeExpense: removeExpense);
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        actions: [
          IconButton(onPressed: addExpenseOverlay, icon: const Icon(Icons.add))
        ],
        title: Text(
          "Expense Trackers",
          style: GoogleFonts.aBeeZee(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
      ),
      body: width < 600 ? compactMode(main, mockExpenses) : regularMode(main, mockExpenses),
    );
  }
}
