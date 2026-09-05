import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth submission does not read ref after its screen is unmounted', () {
    final source = File(
      'lib/church_app/screens/entry/create_auth_account_screen.dart',
    ).readAsStringSync();
    final submitStart = source.indexOf('Future<void> _submit() async');
    final buildStart = source.indexOf('@override\n  Widget build', submitStart);
    final submitSource = source.substring(submitStart, buildStart);
    final finallyStart = submitSource.lastIndexOf('finally {');
    final finallySource = submitSource.substring(finallyStart);

    expect(submitSource, contains('if (!mounted) return;'));
    expect(finallySource, isNot(contains('ref.')));
    expect(finallySource, contains('loadingNotifier.state = false;'));
  });
}
