import 'package:flutter/material.dart';
import 'package:flutter_application/expense_app/expense_model.dart';
import 'package:intl/intl.dart';

class NewExpense extends StatefulWidget {
  const NewExpense({required this.addExpense, super.key});

  final void Function (Expense expense) addExpense;

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {

DateTime? expenseDate;
String expenseName = '';
String expenseAmount = '';
Category categorySelected = Category.leisure;
final dateFormatter = DateFormat.yMd();

  void expenseNameFieldChanged(value){
    expenseName = value;
  }

  void expenseAmountFieldChanged(value){
    expenseAmount = value;
  }

  void addExpenseAction() {
    if (expenseAmount.isNotEmpty && expenseDate != null && int.parse(expenseAmount) >= 0  && expenseName.isNotEmpty) {
      var newExpense = Expense(title: expenseName, amount: int.parse(expenseAmount), date: expenseDate!, type: categorySelected);
      widget.addExpense(newExpense);
      Navigator.pop(context);
    } else {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Invalid Expense"),
        content: const Text("Please enter all fields"),
        actions: [
          TextButton(onPressed: () {
            Navigator.pop(ctx);
          }, child: const Text('Okay'))
        ],
        )
      );
    }
  }

Future<void> presentDatePicker() async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year -1, now.month, now.day);
  final lastDate = now;
  final pickedDate = await showDatePicker(context: context, firstDate: firstDate, lastDate: lastDate);
  setState(() {
    expenseDate = pickedDate;
  });
}

  @override
  Widget build(BuildContext context) {
    final keyBoardSpace = MediaQuery.of(context).viewInsets.bottom;
    
    return LayoutBuilder(builder: (ctx, constraints) {
      final finalWidth = constraints.maxWidth;
      return SizedBox(
      height: double.infinity,
      child: 
        SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, keyBoardSpace + 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextField(
                onChanged: expenseNameFieldChanged,
                maxLength: 50,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  label:  Text('Expense name', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),)
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: expenseAmountFieldChanged,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: '\$',
                        label: Text('Amount', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))
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
                            Text(expenseDate == null ? 'Select Date': dateFormatter.format(expenseDate!)),
                            IconButton(
                                onPressed: presentDatePicker,
                                icon: Icon(Icons.calendar_month, color:Theme.of(context).textTheme.bodySmall?.color,)),
                          ],
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
             
             const SizedBox(height: 20,),
              if(finalWidth < 600 )
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton(onPressed: addExpenseAction, child: const Text('Add Expense')),
                  ),
                  ElevatedButton(onPressed: (){ Navigator.pop(context);}, child: const Text('Cancel'))
                ],
                
              )
            else 
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ElevatedButton(onPressed: addExpenseAction, child: const Text('Add Expense')),
                  ),
                  ElevatedButton(onPressed: (){ Navigator.pop(context);}, child: const Text('Cancel'))
                ],
              )
            ],
          ),
        ),
      ),
    );
    });

    
  }
}