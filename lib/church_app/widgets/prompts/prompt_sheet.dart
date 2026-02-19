import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/prompts/announcement_card_widget.dart';
import 'package:flutter_application/church_app/widgets/prompts/birthday_card_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PromptSheet extends StatelessWidget {
  final PromptType type;
  final PromptSheetModel? promptSheetModel;

  const PromptSheet({
    super.key,
    required this.type,
    this.promptSheetModel,
  });

  @override
  Widget build(BuildContext context) {
    var screenHeight = MediaQuery.of(context).size.height;

    final height = switch (type) {
      PromptType.birthday => screenHeight * 0.8,
      PromptType.announcement => screenHeight * 0.3,
    };

    return SizedBox(
      height: height,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case PromptType.birthday:
        return const BirthDayCard();

      case PromptType.announcement:
        return AnnouncemnetCardWidget(promptSheetModel: promptSheetModel!);
    }
  }
}

enum PromptType {
  birthday,
  announcement,
}

final isBirthdayProvider = Provider<bool>((ref) {
  final user = ref.watch(getCurrentUserProvider).value;
  final now = ref.watch(todayProvider).value ?? DateTime.now();

  if (user == null || user.dob == null) return false;

  final dob = user.dob!.toLocal();
  final today = now.toLocal();
  return dob.day == today.day && dob.month == today.month;
});


final todayProvider = StreamProvider<DateTime>((ref) async* {
  while (true) {
    yield DateTime.now();
    await Future.delayed(const Duration(hours: 1));
  }
});



final isAnnouncementEnabledProvider = Provider<PromptSheetModel?>((ref) {
  final configAsync = ref.watch(appConfigProvider);

  return configAsync.maybeWhen(
    data: (config) => config.promptSheet,
    orElse: () => null,
  );
});

