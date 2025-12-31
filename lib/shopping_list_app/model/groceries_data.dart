import 'package:flutter_application/shopping_list_app/model/categories_data.dart';
import 'package:flutter_application/shopping_list_app/model/category_model.dart';
import 'package:flutter_application/shopping_list_app/model/grocery_model.dart';

final groceryItems = [
  GroceryItem(
      id: 'a',
      name: 'Milk',
      quantity: 1,
      category: categories[Categories.dairy]!),
  GroceryItem(
      id: 'b',
      name: 'Bananas',
      quantity: 5,
      category: categories[Categories.fruit]!),
  GroceryItem(
      id: 'c',
      name: 'Beef Steak',
      quantity: 1,
      category: categories[Categories.meat]!),
];