import 'package:flutter/material.dart';
import 'package:flutter_application/app_starter_menu.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/firebase_options.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

  // void main() async {
  //   WidgetsFlutterBinding.ensureInitialized();
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform
  //   );
  //   runApp(ProviderScope(child: const AppStarterMenu()));
  // }

/* church App */
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
    );
    runApp(ProviderScope(child: 
    MaterialApp(
      home: AppEntry()
    )));
  }