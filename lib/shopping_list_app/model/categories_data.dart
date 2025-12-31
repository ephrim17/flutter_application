import 'package:flutter/material.dart';
import 'package:flutter_application/shopping_list_app/model/category_model.dart';

const categories = {
  Categories.vegetables: CategoryModel(
    'Vegetables',
    Color.fromARGB(255, 0, 255, 128),
  ),
  Categories.fruit: CategoryModel(
    'Fruit',
    Color.fromARGB(255, 145, 255, 0),
  ),
  Categories.meat: CategoryModel(
    'Meat',
    Color.fromARGB(255, 255, 102, 0),
  ),
  Categories.dairy: CategoryModel(
    'Dairy',
    Color.fromARGB(255, 0, 208, 255),
  ),
  Categories.carbs: CategoryModel(
    'Carbs',
    Color.fromARGB(255, 0, 60, 255),
  ),
  Categories.sweets: CategoryModel(
    'Sweets',
    Color.fromARGB(255, 255, 149, 0),
  ),
  Categories.spices: CategoryModel(
    'Spices',
    Color.fromARGB(255, 255, 187, 0),
  ),
  Categories.convenience: CategoryModel(
    'Convenience',
    Color.fromARGB(255, 191, 0, 255),
  ),
  Categories.hygiene: CategoryModel(
    'Hygiene',
    Color.fromARGB(255, 149, 0, 255),
  ),
  Categories.other: CategoryModel(
    'Other',
    Color.fromARGB(255, 0, 225, 255),
  ),
};