import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/screens/select-church-screen.dart';

class AuthEntryScreen extends StatelessWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.church, size: 72),
              const SizedBox(height: 16),
              Text(
                context.t('auth_entry.welcome', fallback: 'Welcome'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SelectChurchScreen(),
                    ),
                  );
                },
                child: Text(
                  context.t('auth_entry.continue', fallback: 'Continue'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
