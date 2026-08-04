import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/screens/entry/reset_password_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PasswordResetCodeScreen extends ConsumerStatefulWidget {
  const PasswordResetCodeScreen({
    super.key,
    required this.email,
    this.churchName = '',
    this.churchLogo = '',
  });

  final String email;
  final String churchName;
  final String churchLogo;

  @override
  ConsumerState<PasswordResetCodeScreen> createState() =>
      _PasswordResetCodeScreenState();
}

class _PasswordResetCodeScreenState
    extends ConsumerState<PasswordResetCodeScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate() || _isVerifying) return;
    final repository = ref.read(authRepositoryProvider);
    setState(() => _isVerifying = true);
    try {
      final resetToken = await repository.verifyPasswordResetCode(
        email: widget.email,
        code: _codeController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: widget.email,
            churchName: widget.churchName,
            resetToken: resetToken,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendSeconds > 0 || _isResending) return;
    final repository = ref.read(authRepositoryProvider);
    setState(() => _isResending = true);
    try {
      await repository.requestPasswordResetCode(
        email: widget.email,
        churchName: widget.churchName,
      );
      if (!mounted) return;
      _codeController.clear();
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('auth.code_resent'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: context.t('auth.verify_code_title')),
      ),
      body: SafeArea(
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
                    Center(
                      child: ChurchLogoAvatar(
                        logo: widget.churchLogo,
                        size: 84,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      context.t('auth.verify_code_title'),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.t(
                        'auth.verify_code_message',
                        parameters: {'email': widget.email},
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    AppTextField(
                      controller: _codeController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: context.t('auth.verification_code'),
                        counterText: '',
                      ),
                      maxLength: 6,
                      validator: (value) => value?.trim().length == 6
                          ? null
                          : context.t('auth.code_required'),
                      onFieldSubmitted: (_) => _verifyCode(),
                    ),
                    const SizedBox(height: 20),
                    SolidButton(
                      label: context.t('auth.verify_code'),
                      isLoading: _isVerifying,
                      onPressed: _verifyCode,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendSeconds == 0 && !_isResending
                          ? _resendCode
                          : null,
                      child: Text(
                        _resendSeconds == 0
                            ? context.t('auth.resend_code')
                            : context.t(
                                'auth.resend_code_in',
                                parameters: {'seconds': _resendSeconds},
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
