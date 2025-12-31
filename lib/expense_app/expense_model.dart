import "package:flutter/material.dart";
import "package:uuid/uuid.dart";

const uuid = Uuid();

enum ExpenseCategory {
  food,
  travel,
  leisure,
  work
}

const categoryIcons = {
  ExpenseCategory.food: Icons.lunch_dining,
  ExpenseCategory.travel: Icons.travel_explore,
  ExpenseCategory.leisure: Icons.leaderboard,
  ExpenseCategory.work: Icons.work,
};

class Expense {
    final String id;
    final String title;
    final num amount;
    final DateTime date;
    final ExpenseCategory type;

    Expense({
      required this.title,
      required this.amount,
      required this.date,
      required this.type,
    }): id = uuid.v4();
}

class ExpenseBucket {

   const ExpenseBucket( {
    required this.category,
    required this.expenses
  });

 ExpenseBucket.forCategory(List<Expense> allExpenses,  this.category)
  : expenses = allExpenses.where((item) => item.type == category).toList();

  final ExpenseCategory category;
  final List<Expense> expenses;

  double get totalExpenses {
    double sum = 0;
    for (final expense in expenses) {
      sum += expense.amount;
    }
    return sum;
  }

}