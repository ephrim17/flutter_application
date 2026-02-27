import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';

class LoginScreen extends ConsumerWidget {
  //const LoginScreen({super.key});

  final String churchId;
  final String churchName;

  const LoginScreen({
    super.key,
    required this.churchId,
    required this.churchName,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final isLoading = ref.watch(logginAccessLoadingProvider);

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: "Login")),
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
                onPressed: isLoading
                    ? null
                    : () async {
                        if (emailCtrl.text.isEmpty ||
                            passCtrl.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please fill all fields (password min 6 chars)'),
                            ),
                          );
                          return;
                        }
                        ref.read(logginAccessLoadingProvider.notifier).state =
                            true;
                        try {
                          await ref.read(authRepositoryProvider).signIn(
                                email: emailCtrl.text.trim(),
                                password: passCtrl.text,
                              );

                          ref.read(logginAccessLoadingProvider.notifier).state =
                              false;
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AppEntry()),
                            (route) => false,
                          );
                        } catch (e) {
                          ref.read(logginAccessLoadingProvider.notifier).state =
                              false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
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
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
