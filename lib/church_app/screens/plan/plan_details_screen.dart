import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PlanDetailsScreen extends StatefulWidget {
  final String month;

  const PlanDetailsScreen({super.key, required this.month});

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  List _items = [];

  Future<void> readJson() async {
    final String response = await rootBundle.loadString('assets/json/\${widget.month.toLowerCase()}_plan.json');
    final data = await json.decode(response);
    setState(() {
      _items = data;
    });
  }

  @override
  void initState() {
    super.initState();
    readJson();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('\${widget.month} Plan'),
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(_items[index]["title"]),
              subtitle: Text(_items[index]["description"]),
              trailing: Text(_items[index]["time"]),
            ),
          );
        },
      ),
    );
  }
}
