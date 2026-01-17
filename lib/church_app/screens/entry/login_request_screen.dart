
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/widgets/pending_approval_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginRequestScreen extends ConsumerWidget {
  const LoginRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Request Access')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Enter Name'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Enter Email'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Enter Password'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(authRepositoryProvider)
                    .requestAccess(
                      name: nameCtrl.text,
                      email: emailCtrl.text,
                      password: passCtrl.text,
                    );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request sent. Wait for admin approval.',
                    ),
                  ),
                );

                 if (!context.mounted) return;

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PendingApprovalWidget(),
                        ),
                      );
              },
              child: const Text('Request Access'),
            ),
          ],
        ),
      ),
    );
  }
}