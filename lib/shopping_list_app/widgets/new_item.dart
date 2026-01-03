import 'package:flutter/material.dart';
import 'package:flutter_application/quiz_app/answerbutton.dart';
import 'package:flutter_application/shopping_list_app/model/categories_data.dart';

class NewItem extends StatefulWidget {
  const NewItem({super.key});

  @override
  State<NewItem> createState() => _NewItemState();
}

class _NewItemState extends State<NewItem> {
  final formKey = GlobalKey<FormState>();

  var itemName = '';
  var itemQuantity = 1;
  var itemCategory = categories.entries.first.value;

  void saveItem() {
    var currentState = formKey.currentState;
    if (currentState != null) {
      currentState.save();
      currentState.validate();
    }
  }

  void resetItem() {
    var currentState = formKey.currentState;
    if (currentState != null) {
      currentState.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    maxLength: 50,
                    decoration: InputDecoration(labelText: 'Item Name'),
                    onSaved: (newValue) {
                      itemName = newValue ?? '';
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an item name';
                      }
                      return null;
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                          ),
                          onSaved: (newValue) => {
                            itemQuantity = int.tryParse(newValue ?? '1') ?? 1
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a quantity';
                            }
                            if (int.tryParse(value) == null ||
                                int.parse(value) <= 0) {
                              return 'Please enter a valid positive number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField(
                          value: itemCategory,
                          items: [
                            for (final category in categories.entries)
                              DropdownMenuItem(
                                value: category.value,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: category.value.color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(category.value.name)
                                  ],
                                ),
                              )
                          ],
                          onChanged: (value) => {
                            setState(() {
                              itemCategory = value!;
                            })
                          },
                          decoration: InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: AnswerButton(
                      answerText: 'Reset',
                      onPressed: (String value) {
                        resetItem();
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: AnswerButton(
                      answerText: 'Add Item ',
                      onPressed: (String value) {
                        saveItem();
                      },
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
