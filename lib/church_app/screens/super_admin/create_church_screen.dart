import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/picked_image_data.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/services/super_admin/super_admin_church_service.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class CreateChurchScreen extends ConsumerStatefulWidget {
  const CreateChurchScreen({
    super.key,
    this.church,
    this.publicRegistrationMode = false,
  });

  final Church? church;
  final bool publicRegistrationMode;

  @override
  ConsumerState<CreateChurchScreen> createState() => _CreateChurchScreenState();
}

class _CreateChurchScreenState extends ConsumerState<CreateChurchScreen> {
  final _nameController = TextEditingController();
  final _pastorController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  int _currentStep = 0;
  bool _enabled = true;
  bool _setupChurchAccount = true;
  bool _isSubmitting = false;
  PickedImageData? _logoImage;
  PickedImageData? _pastorPhotoImage;
  late String _existingLogoUrl;
  late String _existingPastorPhotoUrl;

  bool get _isEditMode => widget.church != null;
  bool get _isPublicRegistrationMode => widget.publicRegistrationMode;

  bool get _canSubmit => !_isSubmitting && _validate(context) == null;

  @override
  void initState() {
    super.initState();
    final church = widget.church;
    _existingLogoUrl = church?.logo ?? '';
    _existingPastorPhotoUrl = church?.pastorPhoto ?? '';

    if (church != null) {
      _nameController.text = church.name;
      _pastorController.text = church.pastorName;
      _addressController.text = church.address;
      _contactController.text = church.contact;
      _emailController.text = church.email;
      _enabled = church.enabled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pastorController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  String _slugifyChurchId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _generateTemporaryPassword() {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'TempA1!${seed.substring(seed.length - 8)}';
  }

  bool get _showsAdminInputs => !_isEditMode;

  List<String> get _stepTitles => const <String>[
        'Church Details',
        'Pastor Details',
        'Admin Details',
      ];

  double get _stepProgress => (_currentStep + 1) / _stepTitles.length;

  String get _headerChurchName {
    final typedName = _nameController.text.trim();
    if (typedName.isNotEmpty) return typedName;
    if (_isEditMode) return 'Edit Church';
    return _isPublicRegistrationMode ? 'Register Church' : 'Create Church';
  }

  String get _headerLogoUrl => _logoImage == null ? _existingLogoUrl : '';

  String? _validateStep(BuildContext context, int stepIndex) {
    final name = _nameController.text.trim();
    final churchId = _slugifyChurchId(name);
    final address = _addressController.text.trim();
    final contact = _contactController.text.trim();
    final email = _emailController.text.trim();
    final adminName = _adminNameController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    final adminPhone = _adminPhoneController.text.trim();

    switch (stepIndex) {
      case 0:
        if (name.isEmpty) {
          return context.t(
            'super_admin.name_required',
            fallback: 'Please enter the church name',
          );
        }
        if (churchId.isEmpty) {
          return context.t(
            'super_admin.id_required',
            fallback: 'Please enter the church ID',
          );
        }
        if (!RegExp(r'^[a-z0-9_]+$').hasMatch(churchId)) {
          return context.t(
            'super_admin.id_invalid',
            fallback:
                'Church ID can contain only lowercase letters, numbers, and underscores',
          );
        }
        if (_logoImage == null && _existingLogoUrl.trim().isEmpty) {
          return context.t(
            'super_admin.logo_required',
            fallback: 'Please pick a church logo',
          );
        }
        if (address.isEmpty) {
          return context.t(
            'super_admin.address_required',
            fallback: 'Please enter the church address',
          );
        }
        if (contact.isEmpty) {
          return context.t(
            'super_admin.contact_required',
            fallback: 'Please enter the church contact',
          );
        }
        if (email.isEmpty) {
          return context.t(
            'super_admin.email_required',
            fallback: 'Please enter the church email',
          );
        }
        if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
          return context.t(
            'auth.email_address_invalid',
            fallback: 'Please enter a valid email address',
          );
        }
        return null;
      case 1:
        if (_pastorPhotoImage == null &&
            _existingPastorPhotoUrl.trim().isEmpty) {
          return context.t(
            'super_admin.pastor_photo_required',
            fallback: 'Please pick a pastor photo',
          );
        }
        return null;
      case 2:
        if (_isEditMode) return null;
        if (adminName.isEmpty) {
          return context.t(
            'super_admin.admin_name_required',
            fallback: 'Please enter the admin name',
          );
        }
        if (adminEmail.isEmpty) {
          return context.t(
            'super_admin.admin_email_required',
            fallback: 'Please enter the admin email',
          );
        }
        if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$')
            .hasMatch(adminEmail)) {
          return context.t(
            'auth.email_address_invalid',
            fallback: 'Please enter a valid email address',
          );
        }
        if (adminPhone.isEmpty) {
          return context.t(
            'super_admin.admin_phone_required',
            fallback: 'Please enter the admin phone',
          );
        }
        return null;
      default:
        return null;
    }
  }

  String? _validate(BuildContext context) {
    final name = _nameController.text.trim();
    final churchId = _slugifyChurchId(name);
    final address = _addressController.text.trim();
    final contact = _contactController.text.trim();
    final email = _emailController.text.trim();
    final adminName = _adminNameController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    final adminPhone = _adminPhoneController.text.trim();

    if (name.isEmpty) {
      return context.t(
        'super_admin.name_required',
        fallback: 'Please enter the church name',
      );
    }
    if (churchId.isEmpty) {
      return context.t(
        'super_admin.id_required',
        fallback: 'Please enter the church ID',
      );
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(churchId)) {
      return context.t(
        'super_admin.id_invalid',
        fallback:
            'Church ID can contain only lowercase letters, numbers, and underscores',
      );
    }
    if (_logoImage == null && _existingLogoUrl.trim().isEmpty) {
      return context.t(
        'super_admin.logo_required',
        fallback: 'Please pick a church logo',
      );
    }
    if (_pastorPhotoImage == null && _existingPastorPhotoUrl.trim().isEmpty) {
      return context.t(
        'super_admin.pastor_photo_required',
        fallback: 'Please pick a pastor photo',
      );
    }
    if (address.isEmpty) {
      return context.t(
        'super_admin.address_required',
        fallback: 'Please enter the church address',
      );
    }
    if (contact.isEmpty) {
      return context.t(
        'super_admin.contact_required',
        fallback: 'Please enter the church contact',
      );
    }
    if (email.isEmpty) {
      return context.t(
        'super_admin.email_required',
        fallback: 'Please enter the church email',
      );
    }
    if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      return context.t(
        'auth.email_address_invalid',
        fallback: 'Please enter a valid email address',
      );
    }
    if (_isEditMode) {
      return null;
    }
    if (adminName.isEmpty) {
      return context.t(
        'super_admin.admin_name_required',
        fallback: 'Please enter the admin name',
      );
    }
    if (adminEmail.isEmpty) {
      return context.t(
        'super_admin.admin_email_required',
        fallback: 'Please enter the admin email',
      );
    }
    if (!RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(adminEmail)) {
      return context.t(
        'auth.email_address_invalid',
        fallback: 'Please enter a valid email address',
      );
    }
    if (adminPhone.isEmpty) {
      return context.t(
        'super_admin.admin_phone_required',
        fallback: 'Please enter the admin phone',
      );
    }
    return null;
  }

  Future<void> _pickLogo() async {
    await _pickImage((image) {
      _logoImage = image;
    });
  }

  Future<void> _pickPastorPhoto() async {
    await _pickImage((image) {
      _pastorPhotoImage = image;
    });
  }

  Future<void> _pickImage(void Function(PickedImageData image) assign) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    final image = await PickedImageData.fromXFile(file);
    if (image == null || !mounted) return;
    setState(() {
      assign(image);
    });
  }

  Future<void> _submit() async {
    final validationError = _validate(context);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final service = SuperAdminChurchService(ref.read(firestoreProvider));
    final normalizedChurchId = _slugifyChurchId(_nameController.text.trim());

    try {
      final churchEmail = _emailController.text.trim();

      if (_isEditMode) {
        if (await service.churchEmailExists(
          churchEmail,
          excludeChurchId: widget.church!.id,
        )) {
          throw const CreateChurchException('duplicate-email');
        }
      } else if (await service.churchEmailExists(churchEmail)) {
        throw const CreateChurchException('duplicate-email');
      }

      if (_isEditMode) {
        await service.updateChurch(
          UpdateChurchInput(
            churchId: widget.church!.id,
            name: _nameController.text.trim(),
            pastorName: _pastorController.text.trim(),
            address: _addressController.text.trim(),
            contact: _contactController.text.trim(),
            email: _emailController.text.trim(),
            enabled: _enabled,
            existingLogoUrl: _existingLogoUrl,
            existingPastorPhotoUrl: _existingPastorPhotoUrl,
            logoImage: _logoImage,
            pastorPhotoImage: _pastorPhotoImage,
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      String? createdAdminUid;
      String? createdAdminEmail;
      var createResult = 'created_without_account';
      final enteredAdminName = _adminNameController.text.trim();
      final enteredAdminEmail = _adminEmailController.text.trim().toLowerCase();
      final enteredAdminPhone = _adminPhoneController.text.trim();

      if (_setupChurchAccount && !_isPublicRegistrationMode) {
        final createdAccount = await ref
            .read(authRepositoryProvider)
            .createFirebaseAccountForAdmin(
              email: enteredAdminEmail,
              password: _generateTemporaryPassword(),
            );
        createdAdminUid = createdAccount.uid;
        createdAdminEmail = createdAccount.email;
      }

      await service.createChurch(
        CreateChurchInput(
          churchId: normalizedChurchId,
          name: _nameController.text.trim(),
          pastorName: _pastorController.text.trim(),
          pastorPhotoImage: _pastorPhotoImage!,
          address: _addressController.text.trim(),
          contact: _contactController.text.trim(),
          email: churchEmail,
          logoImage: _logoImage!,
          enabled: _isPublicRegistrationMode ? false : _enabled,
          setupChurchAccount:
              _isPublicRegistrationMode ? false : _setupChurchAccount,
          registrationSource:
              _isPublicRegistrationMode ? 'public' : 'super_admin',
          adminUid: createdAdminUid,
          adminName: enteredAdminName,
          adminEmail: createdAdminEmail ?? enteredAdminEmail,
          adminPhone: enteredAdminPhone,
        ),
      );

      if (_setupChurchAccount &&
          !_isPublicRegistrationMode &&
          createdAdminEmail != null) {
        createResult = 'created_with_email';
        try {
          await ref.read(authRepositoryProvider).sendPasswordSetupEmail(
                email: createdAdminEmail,
              );
        } catch (_) {
          createResult = 'created_email_failed';
        }
      }

      if (_isPublicRegistrationMode) {
        createResult = 'registered_pending_approval';
      }

      if (!mounted) return;
      Navigator.of(context).pop(createResult);
    } on CreateChurchException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'duplicate-email' => context.t(
            'church.register_duplicate_email',
            fallback: 'A church with this email already exists.',
          ),
        'duplicate-id' => context.t(
            'super_admin.duplicate_id',
            fallback: 'A church with this ID already exists',
          ),
        _ => error.code,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showStepError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goToNextStep() {
    final validationError = _validateStep(context, _currentStep);
    if (validationError != null) {
      _showStepError(validationError);
      return;
    }

    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  void _goToPreviousStep() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep -= 1;
    });
  }

  String _stepSubtitle(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _isPublicRegistrationMode
            ? 'Start with the church identity and contact details people will recognize.'
            : 'Set the core church identity, contact details, and brand image first.';
      case 1:
        return 'Add the pastor presentation details that will be used across the app.';
      case 2:
        return _isEditMode
            ? 'Review access and church status settings for this church.'
            : _setupChurchAccount && !_isPublicRegistrationMode
                ? 'Add the initial admin who will receive account access for this church.'
                : 'Save the initial admin details even if account setup is being deferred.';
      default:
        return '';
    }
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return _buildChurchDetailsStep(context);
      case 1:
        return _buildPastorDetailsStep(context);
      case 2:
        return _buildAdminDetailsStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChurchDetailsStep(BuildContext context) {
    final generatedChurchId = _slugifyChurchId(_nameController.text.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.t(
              'super_admin.church_name_label',
              fallback: 'Church Name',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            generatedChurchId.isEmpty
                ? context.t(
                    'super_admin.church_id_auto_hint',
                    fallback:
                        'Church ID will be generated automatically from the church name.',
                  )
                : '${context.t('super_admin.church_id_preview', fallback: 'Generated Church ID')}: $generatedChurchId',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _addressController,
          onChanged: (_) => setState(() {}),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.t(
              'super_admin.address_label',
              fallback: 'Address',
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _contactController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.t(
              'super_admin.contact_label',
              fallback: 'Contact',
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.t(
              'super_admin.email_label',
              fallback: 'Email',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LogoPickerCard(
          label: context.t(
            'super_admin.logo_label',
            fallback: 'Church Logo',
          ),
          pickText: context.t(
            'super_admin.logo_pick',
            fallback: 'Pick Logo',
          ),
          replaceText: context.t(
            'super_admin.logo_replace',
            fallback: 'Replace Logo',
          ),
          imageBytes: _logoImage?.bytes,
          imageUrl: _logoImage == null ? _existingLogoUrl : null,
          onTap: _isSubmitting ? null : _pickLogo,
        ),
      ],
    );
  }

  Widget _buildPastorDetailsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pastorController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.t(
              'super_admin.pastor_name_label',
              fallback: 'Pastor Name',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _LogoPickerCard(
          label: context.t(
            'super_admin.pastor_photo_label',
            fallback: 'Pastor Photo',
          ),
          pickText: context.t(
            'super_admin.pastor_photo_pick',
            fallback: 'Pick Pastor Photo',
          ),
          replaceText: context.t(
            'super_admin.pastor_photo_replace',
            fallback: 'Replace Pastor Photo',
          ),
          imageBytes: _pastorPhotoImage?.bytes,
          imageUrl: _pastorPhotoImage == null ? _existingPastorPhotoUrl : null,
          onTap: _isSubmitting ? null : _pickPastorPhoto,
        ),
      ],
    );
  }

  Widget _buildAdminDetailsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showsAdminInputs) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.t(
                'super_admin.admin_section_hint',
                fallback: _setupChurchAccount
                    ? 'This admin will be invited to finish account setup.'
                    : 'This admin will be saved under the church config, but no Firebase Auth account will be created yet.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _adminNameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.t(
                'super_admin.admin_name_label',
                fallback: 'Admin Name',
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _adminEmailController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.t(
                'super_admin.admin_email_label',
                fallback: 'Admin Email',
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _adminPhoneController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.t(
                'super_admin.admin_phone_label',
                fallback: 'Admin Phone',
              ),
            ),
          ),
          const SizedBox(height: 18),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Admin creation is only part of the first-time church setup. You can still update this church and change its availability here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (!_isEditMode && !_isPublicRegistrationMode) ...[
          SwitchListTile.adaptive(
            value: _setupChurchAccount,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t(
                'super_admin.setup_account_label',
                fallback: 'Set up church account',
              ),
            ),
            subtitle: Text(
              context.t(
                'super_admin.setup_account_hint',
                fallback: _setupChurchAccount
                    ? 'An initial admin account will be created and invited to finish password setup.'
                    : 'The church will be created without Firebase Auth account setup. You can add access later.',
              ),
            ),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _setupChurchAccount = value;
                    });
                  },
          ),
          const SizedBox(height: 18),
        ],
        if (!_isPublicRegistrationMode) ...[
          SwitchListTile.adaptive(
            value: _enabled,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t(
                'super_admin.enabled_label',
                fallback: 'Enabled',
              ),
            ),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      _enabled = value;
                    });
                  },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: AppBarTitle(
            text: context.t(
              _isEditMode
                  ? 'super_admin.edit_church_title'
                  : _isPublicRegistrationMode
                      ? 'church.register_your_church'
                      : 'super_admin.create_church_title',
              fallback: _isEditMode
                  ? 'Edit Church'
                  : _isPublicRegistrationMode
                      ? 'Register your church'
                      : 'Create Church',
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !_isSubmitting,
        ),
        body: Stack(
          children: [
            LinearScreenBackground(
              solidBackground: true,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: carouselBoxDecoration(context),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(
                                _isEditMode
                                    ? 'super_admin.edit_church_title'
                                    : _isPublicRegistrationMode
                                        ? 'church.register_your_church'
                                        : 'super_admin.create_church_title',
                                fallback: _isEditMode
                                    ? 'Edit Church'
                                    : _isPublicRegistrationMode
                                        ? 'Register your church'
                                        : 'Create Church',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.t(
                                _isEditMode
                                    ? 'super_admin.edit_church_subtitle'
                                    : _isPublicRegistrationMode
                                        ? 'church.register_subtitle'
                                        : 'super_admin.create_church_subtitle',
                                fallback: _isEditMode
                                    ? 'Update the selected church details and media.'
                                    : _isPublicRegistrationMode
                                        ? 'Share your church details. It will stay hidden until a super admin approves it.'
                                        : 'Create a new church and bootstrap the essential starter structure.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: carouselBoxDecoration(context),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            if (_logoImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Image.memory(
                                  _logoImage!.bytes,
                                  height: 84,
                                  width: 84,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              ChurchLogoAvatar(
                                logo: _headerLogoUrl,
                                size: 84,
                              ),
                            const SizedBox(height: 14),
                            _ChurchFlowHeader(
                              title: _headerChurchName,
                              stepIndex: _currentStep,
                              stepCount: _stepTitles.length,
                              progress: _stepProgress,
                            ),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _ChurchStepShell(
                                key: ValueKey<int>(_currentStep),
                                title: _stepTitles[_currentStep],
                                subtitle: _stepSubtitle(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStepContent(context),
                                    const SizedBox(height: 22),
                                    Row(
                                      children: [
                                        if (_currentStep > 0)
                                          Expanded(
                                            child: SolidButton(
                                              label: 'Back',
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : _goToPreviousStep,
                                            ),
                                          ),
                                        if (_currentStep > 0)
                                          const SizedBox(width: 12),
                                        Expanded(
                                          child: SolidButton(
                                            label: _currentStep ==
                                                    _stepTitles.length - 1
                                                ? context.t(
                                                    _isEditMode
                                                        ? 'super_admin.edit_action'
                                                        : _isPublicRegistrationMode
                                                            ? 'church.register_your_church'
                                                            : 'super_admin.create_action',
                                                    fallback: _isEditMode
                                                        ? 'Update Church'
                                                        : _isPublicRegistrationMode
                                                            ? 'Register your church'
                                                            : 'Create Church',
                                                  )
                                                : 'Continue',
                                            onPressed: _currentStep ==
                                                    _stepTitles.length - 1
                                                ? (_canSubmit ? _submit : null)
                                                : (_isSubmitting
                                                    ? null
                                                    : _goToNextStep),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSubmitting) ...[
              const ModalBarrier(
                dismissible: false,
                color: Color(0x66000000),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: carouselBoxDecoration(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        context.t(
                          _isEditMode
                              ? 'super_admin.edit_loading'
                              : _isPublicRegistrationMode
                                  ? 'church.register_loading'
                                  : 'super_admin.create_loading',
                          fallback: _isEditMode
                              ? 'Updating church...'
                              : _isPublicRegistrationMode
                                  ? 'Registering church...'
                                  : 'Creating church...',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogoPickerCard extends StatelessWidget {
  const _LogoPickerCard({
    required this.label,
    required this.pickText,
    required this.replaceText,
    required this.imageBytes,
    required this.imageUrl,
    required this.onTap,
  });

  final String label;
  final String pickText;
  final String replaceText;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || (imageUrl ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 140,
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: hasImage
                    ? (imageBytes != null
                        ? Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ))
                    : Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasImage ? replaceText : pickText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChurchFlowHeader extends StatelessWidget {
  const _ChurchFlowHeader({
    required this.title,
    required this.stepIndex,
    required this.stepCount,
    required this.progress,
  });

  final String title;
  final int stepIndex;
  final int stepCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${stepIndex + 1} of $stepCount',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChurchStepShell extends StatelessWidget {
  const _ChurchStepShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: carouselBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
