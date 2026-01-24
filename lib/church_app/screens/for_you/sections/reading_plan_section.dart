import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/plan/plan_list_screen.dart';
import 'package:flutter_application/church_app/screens/home/home_screen.dart';
import 'package:flutter_application/church_app/widgets/section_header_widget.dart';

class ReadingPlanSection implements MasterSection {
  const ReadingPlanSection();

  @override
  String get id => 'readingPlan';

  @override
  int get order => 30;

  @override
  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SectionHeader(text: "Reading Plans"),
              const SizedBox(height: 8),
              PlanListScreen()
            ],
          ),
        ),
      ),
    ];
  }
}
