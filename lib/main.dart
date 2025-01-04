import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/app_starter_menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((fun){
    runApp(const AppStarterMenu());
  });
}
