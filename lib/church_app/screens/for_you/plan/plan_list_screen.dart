import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/for_you/plan/plan_details_screen.dart';
import 'package:flutter_application/church_app/widgets/plan/plan_card.dart';

class PlanListScreen extends StatelessWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final List<Gradient> gradients = [
      const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
      const LinearGradient(colors: [Colors.purple, Colors.purpleAccent]),
      const LinearGradient(colors: [Colors.green, Colors.lightGreenAccent]),
      const LinearGradient(colors: [Colors.orange, Colors.deepOrangeAccent]),
      const LinearGradient(colors: [Colors.red, Colors.redAccent]),
      const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
      const LinearGradient(colors: [Colors.pink, Colors.pinkAccent]),
      const LinearGradient(colors: [Colors.amber, Colors.yellowAccent]),
      const LinearGradient(colors: [Colors.indigo, Colors.indigoAccent]),
      const LinearGradient(colors: [Colors.cyan, Colors.cyanAccent]),
      const LinearGradient(colors: [Colors.brown, Color(0xFF8D6E63)]),
      const LinearGradient(colors: [Colors.grey, Colors.blueGrey]),
    ];

    return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: months.length,
          itemBuilder: (context, index) {
            return  PlanCard(
                month: months[index],
                gradient: gradients[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlanDetailsScreen(month: months[index]),
                    ),
                  );
                },
              );
          },
        ),
      );
  }
}
