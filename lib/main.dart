import 'package:flutter/material.dart';
import 'package:flutter_application/app_starter_menu.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  runApp(ProviderScope(child: const AppStarterMenu()));
}
