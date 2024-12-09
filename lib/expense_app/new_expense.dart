import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_model.dart';
import 'package:intl/intl.dart';

class NewExpense extends StatefulWidget {
  const NewExpense({super.key});

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {

var expenseDate = 'Select date';
var expenseName = '';
var expenseAmount = '';
Category categorySelected = Category.leisure;

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
        mainAxisAlignment: MainAxisAlignment.start,
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(expenseDate),
                        IconButton(
                            onPressed: presentDatePicker,
                            icon: const Icon(Icons.calendar_month)),
                      ],
                    ),
                    const SizedBox(height: 8,),
                    const Divider(
                      height: 0,
                      color: Color.fromARGB(255, 104, 107, 104),
                      thickness: 1,
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20.0,),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
            const Text("Category: ", style: TextStyle(fontSize: 15.5),),
            const SizedBox(width: 20.0,),
            DropdownButton(
                  value: categorySelected,
                  items: Category.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name.toUpperCase())))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) { return; }
                    setState(() {
                      categorySelected = value;
                    });
          })],),
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