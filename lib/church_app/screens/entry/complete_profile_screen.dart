import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

/// The essentials collected once ever (D5): name, phone, dob, gender.
/// Carried forward to `CreateAccountScreen` when collected pre-account (the
/// normal sign-up path — see [CompleteProfileScreen.onContinue]).
class ProfileDraft {
  const ProfileDraft({
    required this.name,
    required this.phone,
    required this.dob,
    required this.gender,
  });

  final String name;
  final String phone;
  final DateTime dob;
  final String gender;
}

/// Signup, once ever (D5) — captures only the essentials before any church
/// is chosen. Two call shapes, both reusing the same form:
///
/// - Normal sign-up path (`onContinue` set): reached from `AuthChoiceScreen`
///   *before* a Firebase account exists — there is no `uid` to write yet, so
///   submitting hands the collected [ProfileDraft] to [onContinue] (which
///   pushes `CreateAccountScreen`) instead of touching Firestore.
/// - Resume path (`onContinue` null, the default): `AppEntry` shows this
///   when a Firebase account exists but its `users/{uid}` doc doesn't (e.g.
///   a sign-up that was abandoned between account creation and profile
///   submission) — submitting writes the identity doc directly using the
///   already-signed-in user. Its own screen rather than a step inside the
///   old combined auth screen precisely so this resume works — see
///   KT Files/architecture/user-church-decoupling-migration.md §5.5.
///
/// The transparent `AppBar` exists only for its automatic back button: in
/// the sign-up path it's always pushed directly on `AuthChoiceScreen`
/// (thanks to `goToSignUp`'s stack-collapsing), so back returns there; in
/// the resume path there's no route beneath it to pop to, so Flutter hides
/// the back arrow entirely rather than showing a dead one.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, this.onContinue});

  final ValueChanged<ProfileDraft>? onContinue;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  static final _phonePattern = RegExp(r'^[6-9]\d{9}$');

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobController.text = DateFormat('d MMM yyyy').format(picked);
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty ||
        !_phonePattern.hasMatch(phone) ||
        _dob == null ||
        _gender.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.t('profile_step.validation_required'))),
      );
      return;
    }

    if (widget.onContinue != null) {
      // Pre-account sign-up path — no Firebase user exists yet, so there is
      // nothing to write here; the draft moves on to CreateAccountScreen.
      widget.onContinue!(
        ProfileDraft(name: name, phone: phone, dob: _dob!, gender: _gender),
      );
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) return;

    setState(() => _isSaving = true);
    try {
      await UserIdentityRepository(firestore: ref.read(firestoreProvider))
          .createIdentity(
        uid: firebaseUser.uid,
        name: name,
        email: (firebaseUser.email ?? '').trim().toLowerCase(),
        phone: phone,
        dob: _dob,
        gender: _gender,
      );
      // No navigation here — AppEntry watches the identity stream and
      // moves on to email-OTP verification once this doc exists.
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(mapFirebaseAuthError(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ref.t('profile_step.title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                ref.t('profile_step.subtitle'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: ref.t('profile_step.name_label'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: ref.t('profile_step.phone_label'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+91  ',
                  prefixStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  counterText: '',
                ),
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDob,
                decoration: InputDecoration(
                  labelText: ref.t('profile_step.dob_label'),
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [
                  for (final option in const [
                    ('male', 'profile_step.gender_male'),
                    ('female', 'profile_step.gender_female'),
                    ('other', 'profile_step.gender_other'),
                  ])
                    ChoiceChip(
                      label: Text(ref.t(option.$2)),
                      selected: _gender == option.$1,
                      onSelected: (_) => setState(() => _gender = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SolidButton(
                label: ref.t('profile_step.continue_action'),
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
