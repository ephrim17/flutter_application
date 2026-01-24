import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Data models
class ReadingPlan {
  final String month;
  final int monthIndex;
  final List<DayPlan> days;

  ReadingPlan({required this.month, required this.monthIndex, required this.days});

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    var daysFromJson = json['days'] as List;
    List<DayPlan> daysList = daysFromJson.map((i) => DayPlan.fromJson(i)).toList();
    return ReadingPlan(
      month: json['month'],
      monthIndex: json['monthIndex'],
      days: daysList,
    );
  }
}

class DayPlan {
  final int day;
  final List<Reading> readings;

  DayPlan({required this.day, required this.readings});

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    var readingsFromJson = json['readings'] as List;
    List<Reading> readingsList = readingsFromJson.map((i) => Reading.fromJson(i)).toList();
    return DayPlan(
      day: json['day'],
      readings: readingsList,
    );
  }
}

class Reading {
  final String book;
  final String chapters;

  Reading({required this.book, required this.chapters});

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      book: json['book'],
      chapters: json['chapters'],
    );
  }
}


class PlanDetailsScreen extends StatefulWidget {
  final String month;

  const PlanDetailsScreen({super.key, required this.month});

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  ReadingPlan? _readingPlan;

  Future<void> readJson() async {
    final String response = await rootBundle.loadString('assets/json/${widget.month.toLowerCase()}_plan.json');
    final data = await json.decode(response);
    setState(() {
      _readingPlan = ReadingPlan.fromJson(data);
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
        title: Text(_readingPlan?.month ?? "${widget.month} Plan"),
      ),
      body: _readingPlan == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _readingPlan!.days.length,
              itemBuilder: (context, index) {
                final dayPlan = _readingPlan!.days[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text("Day ${dayPlan.day}"),
                    children: dayPlan.readings.map((reading) {
                      return ListTile(
                        title: Text(reading.book),
                        trailing: Text("Chapters: ${reading.chapters}"),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
