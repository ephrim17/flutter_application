import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_model.dart';
import 'package:date_formatter/date_formatter.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpenseItem extends StatelessWidget {
  const ExpenseItem({super.key, required this.expense});

  final Expense expense;

  String getFormattedDateString(DateTime value) {
    var date = DateFormatter.formatDateTime(
      dateTime: expense.date,
      outputFormat: 'dd-MM-yyyy'
    );
    var time = DateFormatter.formatDateTime(
      dateTime: expense.date,
      outputFormat: 'HH:mm'
    );
    return ("$date at $time");
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Text(
              expense.title.toUpperCase(),
              style: GoogleFonts.actor(
                  color: const Color.fromARGB(255, 23, 4, 49),
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  expense.amount.toString(),
                  style: GoogleFonts.actor(
                      color: const Color.fromARGB(255, 168, 34, 74),
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                // Text(expense.type.toString()),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    getFormattedDateString(expense.date),
                    style: const TextStyle(
                        color: Color.fromARGB(231, 58, 58, 58),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
