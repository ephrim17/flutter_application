import "package:flutter/material.dart";
import "package:uuid/uuid.dart";

const uuid = Uuid();

enum Category {
  food,
  travel,
  leisure,
  work
}

const categoryIcons = {
  Category.food: Icons.lunch_dining,
  Category.travel: Icons.travel_explore,
  Category.leisure: Icons.leaderboard,
  Category.work: Icons.work,
};

class Expense {
    final String id;
    final String title;
    final num amount;
    final DateTime date;
    final Category type;

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

  final Category category;
  final List<Expense> expenses;

  double get totalExpenses {
    double sum = 0;
    for (final expense in expenses) {
      sum += expense.amount;
    }
    return sum;
  }

}