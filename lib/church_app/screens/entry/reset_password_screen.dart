import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
    this.email = '',
    this.churchName = '',
  });

  final String oobCode;
  final String email;
  final String churchName;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final Future<String> _verifiedEmailFuture;
  bool _isSaving = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _verifiedEmailFuture =
        FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'auth.password_reset_success',
              fallback: 'Password updated. You can sign in now.',
            ),
          ),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return context.t(
        'auth.password_required',
        fallback: 'Please enter a password',
      );
    }
    if (password.length < 8) {
      return context.t(
        'auth.password_min_length',
        fallback: 'Password must be at least 8 characters',
      );
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return context.t(
        'auth.password_uppercase_required',
        fallback: 'Include at least one uppercase letter',
      );
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return context.t(
        'auth.password_number_required',
        fallback: 'Include at least one number',
      );
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value ?? '';
    if (confirmPassword.isEmpty) {
      return context.t(
        'auth.confirm_password_required',
        fallback: 'Please confirm your password',
      );
    }
    if (confirmPassword != _passwordController.text) {
      return context.t(
        'auth.passwords_mismatch',
        fallback: 'Passwords do not match',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t(
            'auth.reset_password_title',
            fallback: 'Reset Password',
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _verifiedEmailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }

          if (snapshot.hasError || widget.oobCode.trim().isEmpty) {
            return _ResetPasswordMessage(
              icon: Icons.link_off_rounded,
              title: context.t(
                'auth.reset_link_invalid_title',
                fallback: 'Reset link expired',
              ),
              message: context.t(
                'auth.reset_link_invalid_message',
                fallback:
                    'Please request a new password reset link and try again.',
              ),
            );
          }

          final email = snapshot.data?.trim().isNotEmpty == true
              ? snapshot.data!.trim()
              : widget.email.trim();

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.lock_reset_rounded,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.t(
                            'auth.choose_new_password',
                            fallback: 'Choose a new password',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _passwordController,
                          obscureText: !_passwordVisible,
                          decoration: InputDecoration(
                            labelText: context.t(
                              'auth.password_label',
                              fallback: 'Password',
                            ),
                            helperText: context.t(
                              'auth.password_helper',
                              fallback: 'Min 8 chars, 1 uppercase, 1 number',
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _confirmPasswordController,
                          obscureText: !_confirmPasswordVisible,
                          decoration: InputDecoration(
                            labelText: context.t(
                              'auth.confirm_password_label',
                              fallback: 'Confirm Password',
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _confirmPasswordVisible =
                                    !_confirmPasswordVisible,
                              ),
                              icon: Icon(
                                _confirmPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 24),
                        SolidButton(
                          label: context.t(
                            'auth.update_password',
                            fallback: 'Update Password',
                          ),
                          isLoading: _isSaving,
                          onPressed: _savePassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResetPasswordMessage extends StatelessWidget {
  const _ResetPasswordMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.error),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
