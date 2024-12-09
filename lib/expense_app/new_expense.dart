import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NewExpense extends StatefulWidget {
  const NewExpense({super.key});

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {

var expenseDate = 'date';
var expenseName = '';
var expenseAmount = '';

  void expenseNameFieldChanged(value){
    expenseName = value;
  }

  void expenseAmountFieldChanged(value){
    expenseAmount = value;
  }

  void addExpenseAction() {
  
  }

Future<void> presentDatePicker() async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year -1, now.month, now.day);
  final lastDate = now;
  final pickedDate = await showDatePicker(context: context, firstDate: firstDate, lastDate: lastDate);
  final dateFormatter = DateFormat.yMd();
  final formattedDate = dateFormatter.format(pickedDate!);
  setState(() {
    expenseDate = formattedDate;
  });
}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TextField(
            onChanged: expenseNameFieldChanged,
            maxLength: 50,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              label: Text('Expense name')
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: expenseAmountFieldChanged,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: '\$',
                    label: Text('Amount')
                  ),
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(expenseDate),
                    IconButton(onPressed: presentDatePicker, icon: const Icon(Icons.calendar_month))
                  ],
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton(onPressed: addExpenseAction, child: const Text('Add Expense')),
          ),
          const SizedBox(height: 10,),
          ElevatedButton(onPressed: (){}, child: const Text('Cancel'))
        ],
      ),
    );
  }
}