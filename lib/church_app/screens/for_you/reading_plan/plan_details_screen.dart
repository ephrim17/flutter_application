import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/reading_plan_model.dart';
import 'package:flutter_application/church_app/screens/for_you/reading_plan/bible_chapter_reader_screen.dart';

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
                        onTap: () {
                          final range = parseChapterRange(reading.chapters);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BibleChapterReaderScreen(
                                bookKey: reading.book, // Genesis, Psalms, etc
                                startChapter: range[0],
                                endChapter: range[1],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}