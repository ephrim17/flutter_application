import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CreateAuthAccountScreen extends ConsumerStatefulWidget {
  const CreateAuthAccountScreen({
    super.key,
    this.initialLoginMode = false,
    this.adminCreateMode = false,
    this.churchId,
    this.churchName,
    this.churchLogo = '',
    this.existingMember,
    this.continueToEditAfterCreate = false,
  });

  final bool initialLoginMode;
  final bool adminCreateMode;
  final String? churchId;
  final String? churchName;
  final String churchLogo;
  final AppUser? existingMember;
  final bool continueToEditAfterCreate;

  @override
  ConsumerState<CreateAuthAccountScreen> createState() =>
      _CreateAuthAccountScreenState();
}

class _CreateAuthAccountScreenState
    extends ConsumerState<CreateAuthAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late bool _isLoginMode;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isLoginMode = widget.initialLoginMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(logginAccessLoadingProvider.notifier).state = false;
        ref.read(forcePreflowThemeProvider.notifier).state =
            !widget.adminCreateMode;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      return context.t('auth.email_required',
          fallback: 'Please enter your email');
    }

    final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return context.t(
        'auth.email_address_invalid',
        fallback: 'Please enter a valid email address',
      );
    }

    if (widget.adminCreateMode) {
      return null;
    }

    if (password.isEmpty) {
      return context.t(
        'auth.password_required',
        fallback: 'Please enter a password',
      );
    }

    if (!_isLoginMode) {
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
      if (confirmPassword != password) {
        return context.t(
          'auth.passwords_mismatch',
          fallback: 'Passwords do not match',
        );
      }
    }

    return null;
  }

  String _generateTemporaryPassword() {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'TempA1!${seed.substring(seed.length - 8)}';
  }

  AppUser _updatedExistingMember({
    required String uid,
    required String email,
  }) {
    final existingMember = widget.existingMember!;
    return AppUser(
      uid: uid,
      name: existingMember.name,
      email: email,
      role: existingMember.role,
      approved: existingMember.approved,
      phone: existingMember.phone,
      contact: existingMember.contact,
      location: existingMember.location,
      address: existingMember.address,
      gender: existingMember.gender,
      category: existingMember.category,
      familyId: existingMember.familyId,
      maritalStatus: existingMember.maritalStatus,
      weddingDay: existingMember.weddingDay,
      financialStabilityRating: existingMember.financialStabilityRating,
      financialSupportRequired: existingMember.financialSupportRequired,
      educationalQualification: existingMember.educationalQualification,
      talentsAndGifts: existingMember.talentsAndGifts,
      churchGroupIds: existingMember.churchGroupIds,
      authToken: existingMember.authToken,
      dob: existingMember.dob,
    );
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    ref.read(logginAccessLoadingProvider.notifier).state = true;
    try {
      if (widget.adminCreateMode) {
        final temporaryPassword = _generateTemporaryPassword();
        final passwordEmailSentMessage = context.t(
          'members.create_member_password_email_sent',
          fallback: ' Password setup email sent to the member.',
        );
        final passwordEmailFailedMessage = context.t(
          'members.create_member_password_email_failed',
          fallback:
              ' Member login created, but the password setup email could not be sent.',
        );
        final createdAccount = await ref
            .read(authRepositoryProvider)
            .createFirebaseAccountForAdmin(
              email: _emailController.text.trim(),
              password: temporaryPassword,
            );
        String passwordEmailFeedback = '';
        try {
          await ref.read(authRepositoryProvider).sendPasswordSetupEmail(
                email: createdAccount.email,
              );
          passwordEmailFeedback = passwordEmailSentMessage;
        } catch (_) {
          passwordEmailFeedback = passwordEmailFailedMessage;
        }

        if (widget.existingMember != null) {
          final repo = MembersRepository(
            firestore: ref.read(firestoreProvider),
            churchId: widget.churchId!,
          );
          await repo.attachFirebaseAuthToMember(
            widget.existingMember!.uid,
            newUid: createdAccount.uid,
            email: createdAccount.email,
          );

          if (!mounted) return;
          if (widget.continueToEditAfterCreate) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LoginRequestScreen(
                  churchId: widget.churchId!,
                  churchName: widget.churchName!,
                  churchLogo: widget.churchLogo,
                  adminCreateMode: true,
                  existingMember: _updatedExistingMember(
                    uid: createdAccount.uid,
                    email: createdAccount.email,
                  ),
                ),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.t('members.create_member_login_success', fallback: 'Member login created successfully.')}$passwordEmailFeedback',
              ),
            ),
          );
          Navigator.of(context).pop();
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginRequestScreen(
              churchId: widget.churchId!,
              churchName: widget.churchName!,
              churchLogo: widget.churchLogo,
              adminCreateMode: true,
              targetUid: createdAccount.uid,
              initialEmail: createdAccount.email,
            ),
          ),
        );
        return;
      }

      if (_isLoginMode) {
        await ref.read(authRepositoryProvider).signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      } else {
        await ref.read(authRepositoryProvider).createFirebaseAccount(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      }

      await ChurchLocalStorage().clearChurch();
      await ChurchLocalStorage().clearSubscribedChurchTopic();
      ref.read(selectedChurchProvider.notifier).state = null;
      ref.invalidate(currentChurchIdProvider);
      ref.invalidate(appUserProvider);
      ref.invalidate(getCurrentUserProvider);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      ref.read(logginAccessLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(logginAccessLoadingProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: widget.adminCreateMode
              ? widget.existingMember != null
                  ? context.t(
                      'members.create_member_login_title',
                      fallback: 'Create Member Login',
                    )
                  : context.t('members.create_member',
                      fallback: 'Create Member')
              : _isLoginMode
                  ? context.t('auth.login', fallback: 'Login')
                  : context.t('auth.register', fallback: 'Register'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Container(
                  decoration: carouselBoxDecoration(context),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingMember != null
                            ? context.t(
                                'members.create_member_login_heading',
                                fallback: 'Create member login',
                              )
                            : widget.adminCreateMode
                                ? context.t(
                                    'members.create_member_account_heading',
                                    fallback: 'Create member account',
                                  )
                                : _isLoginMode
                                    ? context.t(
                                        'auth.welcome_back_heading',
                                        fallback: 'Welcome back',
                                      )
                                    : context.t(
                                        'auth.create_account_heading',
                                        fallback:
                                            'Create your Church Connect account',
                                      ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.existingMember != null
                            ? context.t(
                                'members.create_member_login_subtitle',
                                fallback:
                                    'Create a Church Connect login for this member.',
                              )
                            : widget.adminCreateMode
                                ? context.t(
                                    'members.create_member_account_subtitle',
                                    fallback:
                                        'Enter the member email. We will create the account and send a password setup email.',
                                  )
                                : _isLoginMode
                                    ? context.t(
                                        'auth.login_subtitle',
                                        fallback:
                                            'Sign in with your Church Connect account to continue.',
                                      )
                                    : context.t(
                                        'auth.register_subtitle',
                                        fallback:
                                            'Create your Church Connect first, then request access to your church.',
                                      ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.t(
                            'auth.email_address_label',
                            fallback: 'Email Address',
                          ),
                          helperText: widget.adminCreateMode
                              ? context.t(
                                  'members.create_member_email_helper',
                                  fallback:
                                      'Church Account will use this email and block duplicate accounts automatically.',
                                )
                              : null,
                        ),
                      ),
                      if (!widget.adminCreateMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            labelText: context.t(
                              'auth.password_label',
                              fallback: 'Password',
                            ),
                            helperText: _isLoginMode
                                ? null
                                : context.t(
                                    'auth.password_helper',
                                    fallback:
                                        'Min 8 chars, 1 uppercase, 1 number',
                                  ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_isLoginMode) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _hideConfirmPassword,
                            decoration: InputDecoration(
                              labelText: context.t(
                                'auth.confirm_password_label',
                                fallback: 'Confirm Password',
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _hideConfirmPassword =
                                        !_hideConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _hideConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SolidButton(
                  label: widget.adminCreateMode
                      ? widget.existingMember != null
                          ? context.t(
                              'members.create_member_login_action',
                              fallback: 'Create member login',
                            )
                          : context.t(
                              'members.create_member_account_action',
                              fallback: 'Create member account',
                            )
                      : _isLoginMode
                          ? context.t('auth.login', fallback: 'Login')
                          : context.t('auth.register', fallback: 'Register'),
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.adminCreateMode
                      ? null
                      : isLoading
                          ? null
                          : () {
                              setState(() {
                                _isLoginMode = !_isLoginMode;
                              });
                            },
                  child: Text(
                    widget.adminCreateMode
                        ? widget.existingMember != null
                            ? context.t(
                                'members.create_member_login_footer',
                                fallback:
                                    'This will create login access and send a password setup email.',
                              )
                            : context.t(
                                'members.create_member_account_footer',
                                fallback:
                                    'Member account will be created with this email and Church Account will send a password setup email.',
                              )
                        : _isLoginMode
                            ? context.t(
                                'auth.login_toggle_register',
                                fallback:
                                    'Need a new Church Connect account? Register',
                              )
                            : context.t(
                                'auth.register_toggle_login',
                                fallback:
                                    'Already have a Church Connect account? Login',
                              ),
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
