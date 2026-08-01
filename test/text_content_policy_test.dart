import 'dart:io';

import 'package:flutter_application/church_app/models/app_config_model.dart';
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
