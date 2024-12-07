import 'package:flutter/material.dart';

class NewExpense extends StatefulWidget {
  const NewExpense({super.key});

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {

var expenseName;

void updateExpenseName(String value) {
  expenseName = value;
}



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        children: [
          TextField(
            onChanged: updateExpenseName,
            maxLength: 50,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              label: Text('expense name')
            ),
          ),
          ElevatedButton(onPressed: () {}, child: Text('Add Expense'))
        ],
      ),
    );
  }
}