import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/widgets/prompts/prompt_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home prompts wait for notifications then drain in alert order', () {
    final announcement = PromptSheetModel(
      title: 'Service update',
      desc: 'Doors open early',
      enabled: true,
    );
    final shown = <String>{};

    expect(
      nextEligibleHomePrompt(
        notificationPromptCompleted: false,
        announcement: announcement,
        isBirthday: true,
        shownPromptKeys: shown,
      ),
      isNull,
    );

    final firstAlert = nextEligibleHomePrompt(
      notificationPromptCompleted: true,
      announcement: announcement,
      isBirthday: true,
      shownPromptKeys: shown,
    );
    expect(firstAlert?.type, PromptType.announcement);

    shown.add(promptSessionKey(PromptType.announcement, announcement));
    final secondAlert = nextEligibleHomePrompt(
      notificationPromptCompleted: true,
      announcement: announcement,
      isBirthday: true,
      shownPromptKeys: shown,
    );
    expect(secondAlert?.type, PromptType.birthday);

    shown.add(promptSessionKey(PromptType.birthday));
    expect(
      nextEligibleHomePrompt(
        notificationPromptCompleted: true,
        announcement: announcement,
        isBirthday: true,
        shownPromptKeys: shown,
      ),
      isNull,
    );
  });
}
