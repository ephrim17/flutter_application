import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/entry/forgot_password_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_entry_screen.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';

class AuthOptionsScreen extends StatelessWidget {
  final String churchId;
  final String churchName;

  const AuthOptionsScreen({
    super.key,
    required this.churchId,
    required this.churchName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: "")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.church, size: 72),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(churchId: churchId, churchName: churchName),
                    ),
                  );
                },
                child: const Text("Login"),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginRequestScreen(churchId: churchId, churchName: churchName,),
                    ),
                  );
                },
                child: const Text("Request Access"),
              ),
            ),
  
             const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text("Forgot Password ?"),
              ),
            )
          ],
        ),
      ),
    );
  }
}