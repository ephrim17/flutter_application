import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.churchName = '',
    this.churchLogo = '',
    this.initialEmail = '',
  });

  final String churchName;
  final String churchLogo;
  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail.trim();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final churchId = await ref.read(currentChurchIdProvider.future);
      await FirebaseAnalytics.instance.logEvent(
        name: 'forgot_password_requested',
        parameters: {
          if (churchId != null && churchId.trim().isNotEmpty)
            'church_id': churchId,
          'has_church_context': widget.churchName.trim().isNotEmpty.toString(),
        },
      );
      await ref.read(authRepositoryProvider).sendCustomPasswordResetEmail(
            email: _emailController.text.trim(),
            churchName: widget.churchName,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', '').trim().isEmpty
                  ? context.t(
                      'common.unknown_error',
                      fallback: 'An unknown error occurred.',
                    )
                  : e.toString().replaceFirst('Exception: ', ''),
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
              AppTextField(
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
