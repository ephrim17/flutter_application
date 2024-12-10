import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_list.dart';
import 'package:flutter_application/expense_app/new_expense.dart';
import 'package:google_fonts/google_fonts.dart';

import 'expense_model.dart';

class ExpenseState extends StatefulWidget {
  const ExpenseState({super.key});

  @override
  State<ExpenseState> createState() => _ExpenseStateState();
}

class _ExpenseStateState extends State<ExpenseState> {

  final List<Expense> mockExpenses = [
   Expense(title: "Flutter", amount: 250, date: DateTime.now(), type: Category.work),
   Expense(title: "Flutter 2", amount: 350, date: DateTime.now(), type: Category.leisure)
  ];

  void addExpenseOverlay(){
      showModalBottomSheet(context: context, builder: (ctx) {
       return NewExpense(addExpense: addExpenses);
      });
  }

  void addExpenses(Expense expense){
    setState(() {
      mockExpenses.add(expense);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(onPressed: addExpenseOverlay, icon: const Icon(Icons.add))
          ],
          title: Text("Expense Trackers", style: GoogleFonts.aBeeZee(
            color: Colors.black87,
            fontSize: 20
          )),
          backgroundColor: const Color.fromARGB(255, 249, 212, 0),
        ),
        body: Column(
          children: [
            Expanded(child: ExpenseList(expenses: mockExpenses))
          ],
        ),
      ),
    );
  }
}