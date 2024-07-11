import 'package:flutter/material.dart';
import 'expense_model.dart';

class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key, required this.expenses});


  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) => Text(expenses[index].title),
      );
  }
}