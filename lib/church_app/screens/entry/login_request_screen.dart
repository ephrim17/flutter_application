import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginRequestScreen extends ConsumerWidget {
  LoginRequestScreen({super.key});

  final formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String phone = '';
  String password = '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(requestAccessLoadingProvider);
    final isPasswordVisible = ref.watch(passwordVisibleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Access')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// NAME
              TextFormField(
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                ),
                onSaved: (value) => name = value?.trim() ?? '',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.trim().length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              /// EMAIL
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                ),
                onSaved: (value) => email = value?.trim() ?? '',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }

                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );

                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              /// PHONE
              TextFormField(
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  counterText: '', // hides "0/10"
                ),
                onSaved: (value) => phone = value?.trim() ?? '',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }

                  final phoneRegex = RegExp(r'^[6-9]\d{9}$');

                  if (!phoneRegex.hasMatch(value.trim())) {
                    return 'Enter a valid 10-digit phone number';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 24),

              TextFormField(
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Min 8 chars, 1 uppercase, 1 number',
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      ref.read(passwordVisibleProvider.notifier).state =
                          !isPasswordVisible;
                    },
                  ),
                ),
                onSaved: (value) => password = value ?? '',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Include at least one uppercase letter';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                    return 'Include at least one lowercase letter';
                  }
                  if (!RegExp(r'\d').hasMatch(value)) {
                    return 'Include at least one number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              /// SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final isValid = formKey.currentState!.validate();
                          if (!isValid) return;

                          formKey.currentState!.save();

                          ref
                              .read(requestAccessLoadingProvider.notifier)
                              .state = true;

                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .requestAccess(
                                    name: name.trim(),
                                    email: email.trim(),
                                    password: password,
                                    phone: phone);

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
      ),
    );
  }
}
