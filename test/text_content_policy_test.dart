import 'dart:io';

import 'package:flutter_application/church_app/models/app_config_model.dart';
import 'package:flutter_application/church_app/models/attendance_service_model.dart';
import 'package:flutter_application/church_app/models/communication_models.dart';
import 'package:flutter_application/church_app/models/text_content_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text content replaces named parameters from church defaults', () {
    final content = TextContent.fromMap(null);

    expect(
      content.get(
        'dashboard.approved_count',
        parameters: {'count': 12},
      ),
      '12 approved',
    );
  });

  test('member since label uses the clean English default', () {
    expect(defaultChurchTextContents['members.member_since_label'],
        'Member Since');
  });

  test('dashboard streak copy uses singular grammar for one member', () {
    final content = TextContent.fromMap(null);

    expect(
      content.get(
        'dashboard.strong_streak_count_singular',
        parameters: {'count': 1},
      ),
      '1 member has built a 7+ day rhythm.',
    );
  });

  test('literal translation keys used by the church app have defaults', () {
    final knownKeys = {
      ...preAuthDefaultTextContents.keys,
      ...defaultChurchTextContents.keys,
    };
    final missing = <String>[];
    final keyPattern = RegExp(
      r'''(?:context|ref)\.t\(\s*['\"]([^'\"]+)['\"]''',
      multiLine: true,
    );

    for (final entity
        in Directory('lib/church_app').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in keyPattern.allMatches(source)) {
        final key = match.group(1)!;
        // A key built at runtime (`'prefix.$variable'`) cannot be checked
        // against the defaults by reading the source — the variable's values
        // are not here. Those sets get their own assertion below rather than
        // being reported as missing.
        if (key.contains(r'$')) continue;
        if (!knownKeys.contains(key)) {
          missing.add('${entity.path}: $key');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Add every UI text key to defaultChurchTextContents.',
    );
  });

  test('every runtime-built key set has a default for each of its values', () {
    // The keys the scanner above has to skip, checked by their actual values.
    final knownKeys = {
      ...preAuthDefaultTextContents.keys,
      ...defaultChurchTextContents.keys,
    };
    final missing = <String>[
      for (final type in attendanceServiceTypeKeys)
        if (!knownKeys.contains('attendance.service_type.$type'))
          'attendance.service_type.$type',
      for (final channel in MessageChannel.values)
        if (!knownKeys.contains('communication.channel.${channel.key}'))
          'communication.channel.${channel.key}',
      for (final category in messageCategoryKeys)
        if (!knownKeys.contains('communication.category.$category'))
          'communication.category.$category',
    ];

    expect(
      missing,
      isEmpty,
      reason: 'These are rendered through an interpolated key, which the '
          'source scan above cannot see, so each set is checked by value.',
    );
  });

  test('widgets do not introduce direct static user-facing strings', () {
    final violations = <String>[];
    final directUiLiteral = RegExp(
      r'''(?:Text\(\s*|TextSpan\(\s*text\s*:\s*|AppBarTitle\(\s*text\s*:\s*|(?:title|subtitle|label|labelText|hintText|helperText|tooltip|semanticLabel|description|message|emptyTitle|emptySubtitle|buttonText|emptyText|addLabel|eyebrow|headline|caption|prompt)\s*:\s*)['"]([^'"\n\$]*[A-Za-z][^'"\n\$]*)['"]''',
      multiLine: true,
    );

    for (final entity
        in Directory('lib/church_app').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('text_content_defaults.dart')) continue;

      final source = entity.readAsStringSync();
      for (final match in directUiLiteral.allMatches(source)) {
        final value = match.group(1)!.trim();
        final isTechnicalPlaceholder = value == '#RRGGBB' ||
            RegExp(r'^UCx+$', caseSensitive: false).hasMatch(value);
        if (isTechnicalPlaceholder) continue;

        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        violations.add('${entity.path}:$line: $value');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Move UI copy to defaultChurchTextContents and use context.t/ref.t.',
    );
  });
}
