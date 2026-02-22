import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/services/FCM/FCM_notification_service.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginRequestScreen extends ConsumerStatefulWidget {
  const LoginRequestScreen({super.key});

  @override
  ConsumerState<LoginRequestScreen> createState() => _LoginRequestScreenState();
}

class _LoginRequestScreenState extends ConsumerState<LoginRequestScreen> {
  final formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String phone = '';
  String password = '';
  String confirmPassword = '';
  DateTime? dob;

  static const double height = 20;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(requestAccessLoadingProvider);
    final isPasswordVisible = ref.watch(passwordVisibleProvider);
    final isConfirmPasswordVisible = ref.watch(confirmPasswordVisibleProvider);

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: "Request Access")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAME
                TextFormField(
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    helperText: 'Name should have only characters, not numbers',
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

                const SizedBox(height: height),

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

                const SizedBox(height: height),

                /// PHONE
                TextFormField(
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    counterText: '',
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

                const SizedBox(height: height),

                /// DOB
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Select your date of birth',
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  controller: TextEditingController(
                    text: dob == null
                        ? ''
                        : '${dob!.day.toString().padLeft(2, '0')}/'
                            '${dob!.month.toString().padLeft(2, '0')}/'
                            '${dob!.year}',
                  ),
                  onTap: () async {
                    FocusScope.of(context).unfocus();

                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );

                    if (pickedDate != null) {
                      setState(() {
                        dob = pickedDate;
                      });
                    }
                  },
                  validator: (_) {
                    if (dob == null) {
                      return 'Please select your date of birth';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: height),

                /// PASSWORD
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
                  onChanged: (value) {
                    password = value; // 👈 IMPORTANT
                  },
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
                    if (!RegExp(r'\d').hasMatch(value)) {
                      return 'Include at least one number';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: height),

                /// CONFIRM PASSWORD
                TextFormField(
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    helperText: 'Password and Confirm passwords must be same',
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        ref
                            .read(confirmPasswordVisibleProvider.notifier)
                            .state = !isConfirmPasswordVisible;
                      },
                    ),
                  ),
                  onChanged: (value) {
                    confirmPassword = value;
                  },
                  onSaved: (value) => confirmPassword = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }

                    if (value != password) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: height * 1.2),

                /// SUBMIT
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            formKey.currentState!.save();
                            if (!context.mounted) return;
                            final enableNotifications =
                                await showNotificationPermissionSheet(context);
                            var authToken = "";
                            if (enableNotifications == true) {
                              final notificationService =
                                  FcmNotificationService();
                              notificationService
                                  .requestNotificationsPermission();
                              authToken = await notificationService
                                  .getFirebaseMessagingToken();
                            }
                            ref
                                .read(requestAccessLoadingProvider.notifier)
                                .state = true;
                            try {
                              await ref
                                  .read(authRepositoryProvider)
                                  .requestAccess(
                                      name: name,
                                      email: email,
                                      password: password,
                                      phone: phone,
                                      dob: dob!,
                                      authToken: authToken);

                              if (!mounted) return;
                               Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AppEntry()),
                            (route) => false,
                          );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(mapFirebaseAuthError(e)),
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
      ),
    );
  }
}
