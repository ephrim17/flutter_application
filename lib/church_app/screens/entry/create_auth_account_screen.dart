import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/helpers/input_validators.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/screens/entry/login_request_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Admin-create-member path only (§9.3 of the migration doc): an
/// admin-created member has no identity doc of their own yet, so the admin
/// supplies just an email here, a temporary password is generated and
/// emailed to them, and `LoginRequestScreen` collects the rest. The
/// self-service sign-in/sign-up path this screen used to also handle
/// (email-first, guessing login vs. register) moved to
/// `AuthChoiceScreen`/`SignInScreen`/`CompleteProfileScreen`/
/// `CreateAccountScreen` — this is now the only remaining caller shape.
class CreateAuthAccountScreen extends ConsumerStatefulWidget {
  const CreateAuthAccountScreen({
    super.key,
    this.churchId,
    this.churchName,
    this.churchLogo = '',
    this.existingMember,
    this.continueToEditAfterCreate = false,
  });

  final String? churchId;
  final String? churchName;
  final String churchLogo;
  final ChurchMembership? existingMember;
  final bool continueToEditAfterCreate;

  @override
  ConsumerState<CreateAuthAccountScreen> createState() =>
      _CreateAuthAccountScreenState();
}

class _CreateAuthAccountScreenState
    extends ConsumerState<CreateAuthAccountScreen> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(logginAccessLoadingProvider.notifier).state = false;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      return context.t('auth.email_required');
    }
    if (!InputValidators.isValidEmail(email)) {
      return context.t('auth.email_address_invalid');
    }
    return null;
  }

  String _generateTemporaryPassword() {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'TempA1!${seed.substring(seed.length - 8)}';
  }

  ChurchMembership _updatedExistingMember({
    required String uid,
    required String email,
  }) {
    final existingMember = widget.existingMember!;
    return ChurchMembership(
      docId: uid,
      churchId: existingMember.churchId,
      uid: uid,
      linkedUid: uid,
      approved: existingMember.approved,
      role: existingMember.role,
      category: existingMember.category,
      familyId: existingMember.familyId,
      churchGroupIds: existingMember.churchGroupIds,
      membershipCurrentStatus: existingMember.membershipCurrentStatus,
      financialStabilityRating: existingMember.financialStabilityRating,
      financialSupportRequired: existingMember.financialSupportRequired,
      displayName: existingMember.displayName,
      displayEmail: email,
      displayPhone: existingMember.displayPhone,
      displayPhotoUrl: existingMember.displayPhotoUrl,
      displayDob: existingMember.displayDob,
      displayGender: existingMember.displayGender,
      displayWeddingDay: existingMember.displayWeddingDay,
      displayMaritalStatus: existingMember.displayMaritalStatus,
      displayEducationalQualification:
          existingMember.displayEducationalQualification,
      displayTalentsAndGifts: existingMember.displayTalentsAndGifts,
      displayLocation: existingMember.displayLocation,
      displayAddress: existingMember.displayAddress,
    );
  }

  Future<void> _submit() async {
    final validationError = _validateEmail();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final loadingNotifier = ref.read(logginAccessLoadingProvider.notifier);
    loadingNotifier.state = true;
    try {
      final temporaryPassword = _generateTemporaryPassword();
      final passwordEmailSentMessage =
          context.t('members.create_member_password_email_sent');
      final passwordEmailFailedMessage =
          context.t('members.create_member_password_email_failed');
      final createdAccount =
          await ref.read(authRepositoryProvider).createFirebaseAccountForAdmin(
                email: _emailController.text.trim(),
                password: temporaryPassword,
              );
      String passwordEmailFeedback = '';
      try {
        await ref.read(authRepositoryProvider).sendPasswordSetupEmail(
              email: createdAccount.email,
              churchName: widget.churchName ?? '',
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
              '${context.t('members.create_member_login_success')}$passwordEmailFeedback',
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(error))),
      );
    } finally {
      loadingNotifier.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(logginAccessLoadingProvider);
    final hasExistingMember = widget.existingMember != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: hasExistingMember
              ? context.t('members.create_member_login_title')
              : context.t('members.create_member'),
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
                        hasExistingMember
                            ? context.t('members.create_member_login_heading')
                            : context
                                .t('members.create_member_account_heading'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasExistingMember
                            ? context.t('members.create_member_login_subtitle')
                            : context
                                .t('members.create_member_account_subtitle'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: context.t('auth.email_address_label'),
                          helperText:
                              context.t('members.create_member_email_helper'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SolidButton(
                  label: hasExistingMember
                      ? context.t('members.create_member_login_action')
                      : context.t('members.create_member_account_action'),
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: null,
                  child: Text(
                    hasExistingMember
                        ? context.t('members.create_member_login_footer')
                        : context.t('members.create_member_account_footer'),
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
