import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/prompts/announcemnet_card_widget.dart';
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

//Prompt Sheet Providers
final isBirthdayProvider = Provider<bool>((ref) {
  final user = ref.watch(getCurrentUserProvider).value;
  if (user == null || user.dob == null) return false;
  final now = DateTime.now();
  final dob = user.dob!;
  return dob.day == now.day && dob.month == now.month;
});



final isAnnouncementEnabledProvider = Provider<PromptSheetModel?>((ref) {
  final configAsync = ref.watch(appConfigProvider);

  return configAsync.maybeWhen(
    data: (config) => config.promptSheet,
    orElse: () => null,
  );
});

