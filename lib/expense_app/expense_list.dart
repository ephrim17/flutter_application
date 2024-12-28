import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_item.dart';
import 'expense_model.dart';

class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key, required this.expenses, required this.removeExpense});

  final List<Expense> expenses;
  final void Function (Expense expense) removeExpense;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (context, index) => Dismissible(
          key: ValueKey(expenses[index]),
          background: Container (
            color: Theme.of(context).colorScheme.errorContainer,
            margin: Theme.of(context).cardTheme.margin,
          ),
          onDismissed: (direction) {
            removeExpense(expenses[index]);
          },
          child: ExpenseItem(
            expense: expenses[index],
          )),
    );
  }
}