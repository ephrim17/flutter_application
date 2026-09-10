import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/auth_choice_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Signup email-OTP gate (§5.5 addendum) — shown by `AppEntry` once
/// `users/{uid}` exists but `emailVerified` is still false. Sends the first
/// code on mount (there is no earlier screen to trigger it, unlike the
/// password-reset flow) and marks `emailVerified` server-side on success;
/// `AppEntry`'s identity stream then moves past this screen on its own.
class EmailOtpVerificationScreen extends ConsumerStatefulWidget {
  const EmailOtpVerificationScreen({super.key});

  @override
  ConsumerState<EmailOtpVerificationScreen> createState() =>
      _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState
    extends ConsumerState<EmailOtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSendingInitialCode = true;

  @override
  void initState() {
    super.initState();
    _requestCode(isInitial: true);
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

  Future<void> _requestCode({bool isInitial = false}) async {
    if (!isInitial && (_resendSeconds > 0 || _isResending)) return;
    final repository = ref.read(authRepositoryProvider);
    setState(() {
      if (isInitial) {
        _isSendingInitialCode = true;
      } else {
        _isResending = true;
      }
    });
    try {
      await repository.requestSignupEmailVerificationCode();
      if (!mounted) return;
      _startResendCountdown();
      if (!isInitial) {
        _codeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('auth.code_resent'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingInitialCode = false;
          _isResending = false;
        });
      }
    }
  }

  /// Signs out and returns to the Sign In/Sign Up choice — this screen is
  /// rendered inline by `AppEntry` (never pushed), so there is no previous
  /// route to pop to; leaving mid-verification has to mean abandoning the
  /// session, not "going back" a step. The account and identity doc already
  /// exist and stay unverified — signing back in returns here.
  Future<void> _signOutAndGoBack() async {
    await ref.read(firebaseAuthProvider).signOut();
    if (!mounted) return;
    ref.invalidate(userIdentityProvider);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
      (route) => false,
    );
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate() || _isVerifying) return;
    final repository = ref.read(authRepositoryProvider);
    setState(() => _isVerifying = true);
    try {
      await repository.verifySignupEmailVerificationCode(
        code: _codeController.text,
      );
      // No navigation here — AppEntry watches the identity stream and
      // moves past this screen on its own once emailVerified flips true.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(firebaseAuthProvider).currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: context.t('auth.verify_code_title')),
        leading: BackButton(onPressed: _signOutAndGoBack),
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
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
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
                        parameters: {'email': email},
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    AppTextField(
                      controller: _codeController,
                      autofocus: true,
                      enabled: !_isSendingInitialCode,
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
                      onPressed: _isSendingInitialCode ? null : _verifyCode,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendSeconds == 0 &&
                              !_isResending &&
                              !_isSendingInitialCode
                          ? () => _requestCode()
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
