import 'package:flutter/material.dart';

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
      body: Center(
        child: Text('New Item Form Goes Here', style: TextStyle(fontSize: 24, color: Theme.of(context).textTheme.bodySmall?.color)),
      ),
      );
  }
}