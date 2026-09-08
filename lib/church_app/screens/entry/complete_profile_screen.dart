import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Signup, once ever (D5) — captures only the essentials before any church
/// is chosen. Its own screen (not a step inside CreateAuthAccountScreen) so
/// an abandoned signup can resume — see
/// KT Files/architecture/user-church-decoupling-migration.md §5.5.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dob;
  String _gender = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty || _dob == null || _gender.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.t('profile_step.validation_required'))),
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
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(mapFirebaseAuthError(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: ref.t('profile_step.title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ref.t('profile_step.title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                ref.t('profile_step.subtitle'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _nameController,
                decoration:
                    InputDecoration(labelText: ref.t('profile_step.name_label')),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: ref.t('profile_step.phone_label')),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dob == null
                      ? ref.t('profile_step.dob_label')
                      : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDob,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
              const SizedBox(height: 24),
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
