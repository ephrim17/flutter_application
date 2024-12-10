import "package:uuid/uuid.dart";

const uuid = Uuid();

enum Category {
  food,
  travel,
  leisure,
  work
}

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