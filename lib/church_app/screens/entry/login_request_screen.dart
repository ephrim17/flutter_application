import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginRequestScreen extends ConsumerWidget {
  const LoginRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final isLoading = ref.watch(requestAccessLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Access')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (nameCtrl.text.isEmpty ||
                            emailCtrl.text.isEmpty ||
                            passCtrl.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please fill all fields (password min 6 chars)'),
                            ),
                          );
                          return;
                        }

                        ref.read(requestAccessLoadingProvider.notifier).state =
                            true;

                        try {
                          await ref.read(authRepositoryProvider).requestAccess(
                                name: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                password: passCtrl.text,
                              );

                          ref
                              .read(requestAccessLoadingProvider.notifier)
                              .state = false;

                          if (!context.mounted) return;
                          Navigator.pop(context);

                          // AppEntry will switch to PendingApproval automatically
                        } catch (e) {
                          ref
                              .read(requestAccessLoadingProvider.notifier)
                              .state = false;

                          final message = mapFirebaseAuthError(e);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } finally {
                          ref
                              .read(requestAccessLoadingProvider.notifier)
                              .state = false;
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Request Access'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
