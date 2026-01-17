import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 📧 Email
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            /// 🔑 Password
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),

            const SizedBox(height: 24),

            /// 🚀 Login
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .signIn(
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text,
                        );

                    if (!context.mounted) return;

                    /// AppEntry will auto-redirect
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
                child: const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
