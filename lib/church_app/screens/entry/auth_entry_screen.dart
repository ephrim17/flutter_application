import 'package:flutter/material.dart';
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
              const Text(
                'Welcome',
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
                child: const Text('Continue'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
