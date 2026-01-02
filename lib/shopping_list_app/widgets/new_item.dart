import 'package:flutter/material.dart';
import 'package:flutter_application/shopping_list_app/model/categories_data.dart';

class NewItem extends StatefulWidget {
  const NewItem({super.key});

  @override
  State<NewItem> createState() => _NewItemState();
}

class _NewItemState extends State<NewItem> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),  
        child: Form(
          child: Column(
            children: [
              TextFormField(
                maxLength: 50,
                decoration: InputDecoration(labelText: 'Item Name'),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a quantity';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField(
                      items: [
                        for (final category in categories.entries)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.value.name),
                          )
                      ],
                      onChanged: (value) => {},
                      decoration: InputDecoration(
                        labelText: 'Category',
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      );
  }
}