import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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


Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
}

/* church App */
  void main() async {
    var lightColorScheme = ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 191, 139, 255),);
    var darkColoScheme = ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 0, 0),);

    WidgetsFlutterBinding.ensureInitialized();
      // await FirebaseAuth.instance.setSettings(
      //   //remove in production
      //   appVerificationDisabledForTesting: true,
      // );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
    );
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

     if (kDebugMode) {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: true,
    );
  }
    runApp(ProviderScope(child: 
    MaterialApp(
        darkTheme: ThemeData().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
        colorScheme: darkColoScheme,),
      theme: ThemeData().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 250, 250),
        colorScheme: lightColorScheme,
      ),
      home: AppEntry()
    )));
  }
