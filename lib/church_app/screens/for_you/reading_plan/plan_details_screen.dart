import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/providers/for_you_sections/reading_plan_progress_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_book_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/progress_bar_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/models/for_you_section_models/reading_plan_model.dart';
import 'package:flutter_application/church_app/models/bible_book_model.dart';

class PlanDetailsScreen extends ConsumerStatefulWidget {
  final String month;

  const PlanDetailsScreen({super.key, required this.month});

  @override
  ConsumerState<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends ConsumerState<PlanDetailsScreen> {
  ReadingPlan? _readingPlan;

  Future<void> readJson() async {
    final String response = await rootBundle
        .loadString('assets/json/${widget.month.toLowerCase()}_plan.json');
    final data = json.decode(response);
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
    final progressState = ref.watch(readingPlanProgressProvider(widget.month));

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: _readingPlan?.month ?? "${widget.month} Plan"),
      ),
      body: _readingPlan == null
          ? const Center(child: CircularProgressIndicator())
          : progressState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (completedDays) {
                final totalDays = _readingPlan!.days.length;
                final completedCount = completedDays.length;

                return Column(
                  children: [
                    /// 🔥 Reusable Progress Widget
                    ReadingProgressBar(
                      current: completedCount,
                      total: totalDays,
                    ),

                    const Divider(height: 1),

                    /// 🔥 Days List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _readingPlan!.days.length,
                        itemBuilder: (context, index) {
                          final dayPlan = _readingPlan!.days[index];
                          final isCompleted =
                              completedDays.contains(dayPlan.day);

                          return Card(
                            color: isCompleted
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.85)
                                : null,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Day ${dayPlan.day}"),
                                  IconButton(
                                    icon: Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isCompleted ? Theme.of(context).colorScheme.secondary : null,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(readingPlanProgressProvider(
                                                  widget.month)
                                              .notifier)
                                          .toggleDay(dayPlan.day);
                                    },
                                  ),
                                ],
                              ),
                              children: dayPlan.readings.map((reading) {
                                return ListTile(
                                  title: Text(reading.book),
                                  trailing:
                                      Text("Chapters: ${reading.chapters}"),
                                  onTap: () {
                                    final range =
                                        parseChapterRange(reading.chapters);

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VerseScreen(
                                          book: BibleBook(
                                            key: reading.book,
                                            name: reading.book,
                                          ),
                                          startChapterIndex: range[0] - 1,
                                          endChapterIndex: range[1] - 1,
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
                    ),
                  ],
                );
              },
            ),
    );
  }
}

List<int> parseChapterRange(String chapters) {
  if (!chapters.contains('-')) {
    final ch = int.parse(chapters.trim());
    return [ch, ch];
  }

  final parts = chapters.split('-');
  return [
    int.parse(parts[0].trim()),
    int.parse(parts[1].trim()),
  ];
}
