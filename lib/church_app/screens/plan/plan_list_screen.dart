import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/plan/plan_details_screen.dart';
import 'package:flutter_application/church_app/widgets/plan/plan_card.dart';

class PlanListScreen extends StatelessWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Plans'),
      ),
      body: SizedBox(
        height: 180,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            PlanCard(
              month: 'January',
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanDetailsScreen(month: 'January'),
                  ),
                );
              },
            ),
            PlanCard(
              month: 'February',
              gradient: const LinearGradient(
                colors: [Colors.purple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlanDetailsScreen(month: 'February'),
                  ),
                );
              },
            ),
            // Add more months here
          ],
        ),
      ),
    );
  }
}
