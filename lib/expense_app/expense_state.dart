import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_list.dart';
import 'package:google_fonts/google_fonts.dart';

import 'expense_model.dart';

class ExpenseState extends StatefulWidget {
  const ExpenseState({super.key});

  @override
  State<ExpenseState> createState() => _ExpenseStateState();
}

class _ExpenseStateState extends State<ExpenseState> {

  final List<Expense> mockExpenses = [
   Expense(title: "Flutter", amount: 250.0, date: DateTime.now(), type: Category.work),
   Expense(title: "Flutter 2", amount: 350.0, date: DateTime.now(), type: Category.leisure)
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Expense Tracker", style: GoogleFonts.aBeeZee(
            color: Colors.black87,
            fontSize: 20
          )),
          backgroundColor: Color.fromARGB(255, 249, 212, 0),
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