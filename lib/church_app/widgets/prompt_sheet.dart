import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/birthday_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptSheet extends StatelessWidget {
  const PromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: BirthDayCard()
    );
  }
}

//Prompt Sheet Providers
final isBirthdayProvider = Provider<bool>((ref) {
  final user = ref.watch(getCurrentUserProvider).value;

  if (user == null || user.dob == null) return false;

  final now = DateTime.now();
  final dob = user.dob!;

  return dob.day == now.day && dob.month == now.month;
});

