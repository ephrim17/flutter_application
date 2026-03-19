import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.churchName = '',
    this.churchLogo = '',
  });

  final String churchName;
  final String churchLogo;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'auth.reset_email_sent',
                fallback: 'Password reset email sent. Check your inbox.',
              ),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ??
                  context.t(
                    'common.unknown_error',
                    fallback: 'An unknown error occurred.',
                  ),
            ),
          ),
        );
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: context.t('auth.forgot_password_title',
              fallback: 'Forgot Password'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChurchLogoAvatar(
                logo: widget.churchLogo,
                size: 84,
              ),
              if (widget.churchName.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  widget.churchName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: context.t('auth.email_label', fallback: 'Email'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return context.t(
                      'auth.email_invalid',
                      fallback: 'Please enter a valid email.',
                    );
                  }
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              SolidButton(
                label: context.t(
                  'auth.send_reset_email',
                  fallback: 'Send Reset Email',
                ),
                isLoading: _isLoading,
                onPressed: _sendResetEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
