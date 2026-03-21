import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/app_user_model.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/loading_access_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/services/FCM/FCM_notification_service.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

class LoginRequestScreen extends ConsumerStatefulWidget {
  final String churchId;
  final String churchName;
  final String churchLogo;
  final bool adminCreateMode;
  final String? targetUid;
  final String? initialEmail;
  final AppUser? existingMember;

  const LoginRequestScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.churchLogo = '',
    this.adminCreateMode = false,
    this.targetUid,
    this.initialEmail,
    this.existingMember,
  });

  @override
  ConsumerState<LoginRequestScreen> createState() => _LoginRequestScreenState();
}

class _LoginRequestScreenState extends ConsumerState<LoginRequestScreen> {
  static const int _stepCount = 5;

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _familyNameController = TextEditingController();

  int _stepIndex = 0;
  DateTime? _dob;
  String _gender = '';
  String _category = '';
  bool _isFetchingLocation = false;
  bool _useExistingFamilyId = false;
  String? _selectedExistingFamilyId;
  late final Future<List<String>> _familyIdsFuture;

  bool get _isEditMode => widget.existingMember != null;

  @override
  void initState() {
    super.initState();
    _familyIdsFuture =
        ref.read(authRepositoryProvider).getFamilyIds(widget.churchId);
    final existingMember = widget.existingMember;
    if (existingMember != null) {
      _nameController.text = existingMember.name;
      _phoneController.text = existingMember.phone;
      _locationController.text = existingMember.location;
      _addressController.text = existingMember.address;
      _dob = existingMember.dob;
      _gender = existingMember.gender.trim().toLowerCase();
      _category = existingMember.category.trim().toLowerCase();

      if (_category == 'family') {
        _selectedExistingFamilyId = existingMember.familyId.trim().isEmpty
            ? null
            : existingMember.familyId.trim();
        _useExistingFamilyId = _selectedExistingFamilyId != null;
        _familyNameController.text =
            _familySeedFromId(existingMember.familyId.trim());
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _fillCurrentLocation() async {
    final serviceDisabledMessage = context.t(
      'auth.location_service_disabled',
      fallback: 'Location services are disabled',
    );
    final permissionDeniedMessage = context.t(
      'auth.location_permission_denied',
      fallback: 'Location permission denied',
    );
    final permissionDeniedForeverMessage = context.t(
      'auth.location_permission_denied_forever',
      fallback:
          'Location permission denied permanently. Enable it from settings.',
    );
    final fetchFailedMessage = context.t(
      'auth.location_fetch_failed',
      fallback: 'Unable to fetch current location',
    );

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw serviceDisabledMessage;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw permissionDeniedMessage;
      }
      if (permission == LocationPermission.deniedForever) {
        throw permissionDeniedForeverMessage;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _locationController.text =
            'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is String ? error : fetchFailedMessage),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  String _resolveFamilyId() {
    if (_category == 'family' &&
        _useExistingFamilyId &&
        _selectedExistingFamilyId != null &&
        _selectedExistingFamilyId!.trim().isNotEmpty) {
      return _selectedExistingFamilyId!.trim();
    }

    final seed = _category == 'family'
        ? _familyNameController.text.trim()
        : _nameController.text.trim();
    if (_category.isEmpty || seed.isEmpty) return '';

    final normalizedSeed = _normalizeCategorySeed(seed);
    if (normalizedSeed.isEmpty) return '';

    return '${_category.toLowerCase()}_${normalizedSeed}_${widget.churchId}';
  }

  String _normalizeCategorySeed(String value) {
    final churchSuffix = widget.churchId.toLowerCase();
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    normalized = normalized
        .replaceFirst(RegExp(r'^(family|individual)_+'), '')
        .replaceFirst(RegExp('_$churchSuffix\$'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return normalized;
  }

  String _formatFamilyOptionLabel(String familyId) {
    final normalized = familyId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return familyId;
    }

    var cleaned = normalized
        .replaceFirst(RegExp(r'^family_'), '')
        .replaceFirst(RegExp(r'^individual_'), '')
        .replaceFirst(RegExp('_${widget.churchId.toLowerCase()}\$'), '');

    final displayName = cleaned
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ')
        .trim();

    if (displayName.isEmpty) {
      return familyId;
    }

    final suffix = displayName.endsWith('s') ? "'" : "'s";
    return '$displayName$suffix family';
  }

  String _familySeedFromId(String familyId) {
    final normalized = familyId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }

    final cleaned = normalized
        .replaceFirst(RegExp(r'^family_'), '')
        .replaceFirst(RegExp('_${widget.churchId.toLowerCase()}\$'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String? _validateCurrentStep() {
    switch (_stepIndex) {
      case 0:
        final name = _nameController.text.trim();
        final phone = _phoneController.text.trim();
        if (name.isEmpty) {
          return context.t('auth.name_required',
              fallback: 'Please enter your name');
        }
        if (name.length < 3) {
          return context.t(
            'auth.name_min_length',
            fallback: 'Name must be at least 3 characters',
          );
        }
        final phoneRegex = RegExp(r'^[6-9]\d{9}$');
        if (!phoneRegex.hasMatch(phone)) {
          return context.t(
            'auth.phone_invalid',
            fallback: 'Enter a valid 10-digit phone number',
          );
        }
        return null;
      case 1:
        if (_gender.isEmpty) {
          return context.t(
            'auth.gender_required',
            fallback: 'Please select your gender',
          );
        }
        if (_dob == null) {
          return context.t(
            'auth.dob_required',
            fallback: 'Please select your date of birth',
          );
        }
        return null;
      case 2:
        if (_category.isEmpty) {
          return context.t(
            'auth.category_required',
            fallback: 'Please select your category',
          );
        }
        if (_category == 'family') {
          if (_useExistingFamilyId &&
              (_selectedExistingFamilyId == null ||
                  _selectedExistingFamilyId!.trim().isEmpty)) {
            return context.t(
              'auth.family_id_required',
              fallback: 'Please select or create a family ID',
            );
          }
          if (!_useExistingFamilyId &&
              _familyNameController.text.trim().isEmpty) {
            return context.t(
              'auth.family_name_required',
              fallback: 'Please enter a family name',
            );
          }
        }
        return null;
      case 3:
        if (_addressController.text.trim().isEmpty) {
          return context.t(
            'auth.address_required',
            fallback: 'Please enter your address',
          );
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _goToStep(int index) async {
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
    );
    if (mounted) {
      setState(() {
        _stepIndex = index;
      });
    }
  }

  Future<void> _handleNext() async {
    final error = _validateCurrentStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (_stepIndex < _stepCount - 1) {
      await _goToStep(_stepIndex + 1);
    }
  }

  Future<void> _submit() async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null && !widget.adminCreateMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your account first before requesting access.'),
        ),
      );
      return;
    }

    final familyId = _resolveFamilyId();
    if (familyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t(
              'auth.family_id_required',
              fallback: 'Please select or create a family ID',
            ),
          ),
        ),
      );
      return;
    }

    final enableNotifications = widget.adminCreateMode
        ? false
        : kIsWeb
            ? false
            : await showNotificationPermissionSheet(context);
    if (!context.mounted) return;

    var authToken = '';
    if (enableNotifications == true) {
      final notificationService = FcmNotificationService();
      notificationService.requestNotificationsPermission();
      authToken = await notificationService.getFirebaseMessagingToken();
    }

    ref.read(requestAccessLoadingProvider.notifier).state = true;
    try {
      if (_isEditMode) {
        final repo = MembersRepository(
          firestore: ref.read(firestoreProvider),
          churchId: widget.churchId,
        );
        await repo.updateMemberDetails(
          widget.existingMember!.uid,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
          address: _addressController.text.trim(),
          gender: _gender,
          category: _category,
          familyId: familyId,
          dob: _dob!,
          familyLabel: _category == 'family' && !_useExistingFamilyId
              ? _familyNameController.text.trim()
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member updated successfully.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      if (!widget.adminCreateMode) {
        final existingDoc = await ref.read(authRepositoryProvider).getChurchUserDoc(
              churchId: widget.churchId,
              uid: firebaseUser!.uid,
            );

        if (existingDoc.exists) {
          final appUser = AppUser.fromFirestore(
            existingDoc.id,
            existingDoc.data() as Map<String, dynamic>,
          );
          ref.read(forcePreflowThemeProvider.notifier).state = !appUser.approved;

          ref.read(selectedChurchProvider.notifier).state = Church(
            id: widget.churchId,
            name: widget.churchName,
            address: '',
            contact: '',
            email: '',
            pastorName: '',
            logo: widget.churchLogo,
            enabled: true,
          );
          ref.invalidate(currentChurchIdProvider);
          unawaited(syncNotificationTopicIfAuthorized(ref));

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => AppEntry(initialUser: appUser),
            ),
            (route) => false,
          );
          return;
        }
      }

      await ref.read(authRepositoryProvider).requestAccess(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            location: _locationController.text.trim(),
            address: _addressController.text.trim(),
            gender: _gender,
            category: _category,
            familyId: familyId,
            dob: _dob!,
            authToken: authToken,
            churchId: widget.churchId,
            familyLabel: _category == 'family' && !_useExistingFamilyId
                ? _familyNameController.text.trim()
                : null,
            targetUid: widget.targetUid,
            targetEmail: widget.initialEmail,
            approved: widget.adminCreateMode,
            createChurchMemberWithoutAuth:
                widget.adminCreateMode && widget.targetUid == null,
          );

      if (widget.adminCreateMode) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member created successfully.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      ref.read(selectedChurchProvider.notifier).state = Church(
        id: widget.churchId,
        name: widget.churchName,
        address: '',
        contact: '',
        email: '',
        pastorName: '',
        logo: widget.churchLogo,
        enabled: true,
      );
      ref.invalidate(currentChurchIdProvider);
      unawaited(syncNotificationTopicIfAuthorized(ref));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(e))),
      );
    } finally {
      ref.read(requestAccessLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(requestAccessLoadingProvider);
    final progress = (_stepIndex + 1) / _stepCount;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(
          text: _isEditMode
              ? context.t('members.edit_member', fallback: 'Edit Member')
              : widget.adminCreateMode
              ? context.t('members.create_member', fallback: 'Create Member')
              : context.t('auth.request_access', fallback: 'Request Access'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StepViewport(
                        churchLogo: widget.churchLogo,
                        churchName: widget.churchName,
                        stepIndex: _stepIndex,
                        stepCount: _stepCount,
                        progress: progress,
                        child: _StepShell(
                          title: _isEditMode
                              ? 'Edit member details'
                              : widget.adminCreateMode
                              ? 'Enter member details'
                              : 'Tell us about you',
                          subtitle: _isEditMode
                              ? 'Update the member details below.'
                              : widget.adminCreateMode
                              ? 'Tell us about your member.'
                              : 'Start with your basic details.',
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: context.t('auth.name_label',
                                      fallback: widget.adminCreateMode
                                          ? 'Member Name'
                                          : 'Your Name'),
                                  helperText: context.t(
                                    'auth.name_helper',
                                    fallback: widget.adminCreateMode
                                        ? 'Enter your member name using letters only'
                                        : 'Name should have only characters, not numbers',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: context.t(
                                    'auth.phone_label',
                                    fallback: widget.adminCreateMode
                                        ? "Member's Phone Number"
                                        : 'Phone Number',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StepViewport(
                        churchLogo: widget.churchLogo,
                        churchName: widget.churchName,
                        stepIndex: _stepIndex,
                        stepCount: _stepCount,
                        progress: progress,
                        child: _StepShell(
                          title: widget.adminCreateMode
                              ? 'Member identity'
                              : 'Identity',
                          subtitle: widget.adminCreateMode
                              ? "What is your member's birthday?"
                              : 'A couple of personal details.',
                          child: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                value: _gender.isEmpty ? null : _gender,
                                decoration: InputDecoration(
                                  labelText: context.t('auth.gender_label',
                                      fallback: widget.adminCreateMode
                                          ? "Member's Gender"
                                          : 'Gender'),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'male', child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'female', child: Text('Female')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _gender = value ?? '';
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().subtract(
                                      const Duration(days: 365 * 18),
                                    ),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      _dob = pickedDate;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: context.t('auth.dob_label',
                                        fallback: 'Date of Birth'),
                                    suffixIcon:
                                        const Icon(Icons.calendar_today),
                                  ),
                                  child: Text(
                                    _dob == null
                                        ? context.t(
                                            'auth.dob_hint',
                                            fallback: widget.adminCreateMode
                                                ? "What is your member's birthday?"
                                                : 'Select your date of birth',
                                          )
                                        : '${_dob!.day.toString().padLeft(2, '0')}/'
                                            '${_dob!.month.toString().padLeft(2, '0')}/'
                                            '${_dob!.year}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StepViewport(
                        churchLogo: widget.churchLogo,
                        churchName: widget.churchName,
                        stepIndex: _stepIndex,
                        stepCount: _stepCount,
                        progress: progress,
                        child: _StepShell(
                          title: 'Household',
                          subtitle: widget.adminCreateMode
                              ? 'Choose whether your member belongs to a family or is an individual.'
                              : 'Choose whether this request is for a family or an individual.',
                          child: FutureBuilder<List<String>>(
                            future: _familyIdsFuture,
                            builder: (context, snapshot) {
                              final familyIds =
                                  snapshot.data ?? const <String>[];
                              final selectedFamilyValue =
                                  familyIds.contains(_selectedExistingFamilyId)
                                      ? _selectedExistingFamilyId
                                      : null;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _category.isEmpty ? null : _category,
                                    decoration: InputDecoration(
                                      labelText: context.t(
                                        'auth.category_label',
                                        fallback: 'Category',
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'family',
                                          child: Text('Family')),
                                      DropdownMenuItem(
                                        value: 'individual',
                                        child: Text('Individual'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _category = value ?? '';
                                        if (_category != 'family') {
                                          _useExistingFamilyId = false;
                                          _selectedExistingFamilyId = null;
                                          _familyNameController.clear();
                                        }
                                      });
                                    },
                                  ),
                                  if (_category == 'family') ...[
                                    const SizedBox(height: 16),
                                    if (familyIds.isNotEmpty)
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          context.t(
                                            'auth.family_existing_toggle',
                                            fallback: 'Use existing family ID',
                                          ),
                                        ),
                                        value: _useExistingFamilyId,
                                        onChanged: (value) {
                                          setState(() {
                                            _useExistingFamilyId = value;
                                            if (!value) {
                                              _selectedExistingFamilyId = null;
                                            }
                                          });
                                        },
                                      ),
                                    const SizedBox(height: 8),
                                    if (familyIds.isNotEmpty &&
                                        _useExistingFamilyId)
                                      DropdownButtonFormField<String>(
                                        value: selectedFamilyValue,
                                        decoration: InputDecoration(
                                          labelText: context.t(
                                            'auth.family_id_label',
                                            fallback: 'Family ID',
                                          ),
                                        ),
                                        items: familyIds
                                            .map(
                                              (familyId) => DropdownMenuItem(
                                                value: familyId,
                                                child: Text(
                                                  _formatFamilyOptionLabel(
                                                      familyId),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedExistingFamilyId = value;
                                          });
                                        },
                                      )
                                    else
                                      TextField(
                                        controller: _familyNameController,
                                        decoration: InputDecoration(
                                          labelText: context.t(
                                            'auth.family_name_label',
                                            fallback: 'Family Name',
                                          ),
                                          helperText: context.t(
                                            'auth.family_name_helper',
                                            fallback:
                                                'Used to generate a new family ID',
                                          ),
                                        ),
                                      ),
                                  ],
                                  if (_category == 'individual') ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      context.t(
                                        'auth.individual_family_hint',
                                        fallback:
                                            'Family ID will be generated automatically',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _resolveFamilyId(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      _StepViewport(
                        churchLogo: widget.churchLogo,
                        churchName: widget.churchName,
                        stepIndex: _stepIndex,
                        stepCount: _stepCount,
                        progress: progress,
                        child: _StepShell(
                          title: 'Where are you located?',
                          subtitle: widget.adminCreateMode
                              ? "Add your member's address. Google Maps location is optional."
                              : 'Add your address. Google Maps location is optional.',
                          child: Column(
                            children: [
                              TextField(
                                controller: _locationController,
                                keyboardType: TextInputType.url,
                                decoration: InputDecoration(
                                  labelText: context.t(
                                    'auth.location_label',
                                    fallback: widget.adminCreateMode
                                        ? "Member's Google Maps Location (Optional)"
                                        : 'Google Maps Location (Optional)',
                                  ),
                                  helperText: context.t(
                                    'auth.location_helper',
                                    fallback: widget.adminCreateMode
                                        ? "Use your member's current location or paste their Google Maps link if you want"
                                        : 'Use current location or paste your Google Maps link if you want',
                                  ),
                                  suffixIcon: _isFetchingLocation
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: _fillCurrentLocation,
                                          icon: const Icon(Icons.my_location),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _isFetchingLocation
                                      ? null
                                      : _fillCurrentLocation,
                                  icon: const Icon(
                                      Icons.location_searching_outlined),
                                  label: Text(
                                    context.t(
                                      'auth.location_use_current',
                                      fallback: widget.adminCreateMode
                                          ? 'Use Member Current Location'
                                          : 'Use Current Location',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _addressController,
                                keyboardType: TextInputType.streetAddress,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: context.t(
                                    'auth.address_label',
                                    fallback: widget.adminCreateMode
                                        ? "Member's Address"
                                        : 'Address',
                                  ),
                                  helperText: context.t(
                                    'auth.address_helper',
                                    fallback: widget.adminCreateMode
                                        ? "Enter your member's address manually"
                                        : 'Enter your address manually',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StepViewport(
                        churchLogo: widget.churchLogo,
                        churchName: widget.churchName,
                        stepIndex: _stepIndex,
                        stepCount: _stepCount,
                        progress: progress,
                        child: _StepShell(
                          title: 'Review',
                          subtitle: _isEditMode
                              ? 'Check the member details before saving your changes.'
                              : widget.adminCreateMode
                              ? 'Check your member details before creating the member.'
                              : 'Check the details before submitting your request.',
                          child: _ReviewCard(
                            rows: [
                              _ReviewRow('Name', _nameController.text.trim()),
                              _ReviewRow('Phone', _phoneController.text.trim()),
                              _ReviewRow('Gender', _gender),
                              _ReviewRow(
                                'Date of Birth',
                                _dob == null
                                    ? ''
                                    : '${_dob!.day.toString().padLeft(2, '0')}/'
                                        '${_dob!.month.toString().padLeft(2, '0')}/'
                                        '${_dob!.year}',
                              ),
                              _ReviewRow('Category', _category),
                              _ReviewRow('Family ID', _resolveFamilyId()),
                              _ReviewRow(
                                  'Location', _locationController.text.trim()),
                              _ReviewRow(
                                  'Address', _addressController.text.trim()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_stepIndex > 0)
                      Expanded(
                        child: SolidButton(
                          label: context.t('common.back', fallback: 'Back'),
                          onPressed: isLoading
                              ? null
                              : () => _goToStep(_stepIndex - 1),
                        ),
                      ),
                    if (_stepIndex > 0) const SizedBox(width: 12),
                    Expanded(
                      child: SolidButton(
                        label: _stepIndex == _stepCount - 1
                            ? _isEditMode
                                ? context.t('common.save', fallback: 'Save')
                                : context.t('common.submit', fallback: 'Submit')
                            : context.t('onboarding.next', fallback: 'Next'),
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : _stepIndex == _stepCount - 1
                                ? _submit
                                : _handleNext,
                      ),
                    ),

                    const SizedBox(height: 30,)
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Step ${stepIndex + 1} of $stepCount'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 10),
          ),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
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

class _StepViewport extends StatefulWidget {
  const _StepViewport({
    required this.churchLogo,
    required this.churchName,
    required this.stepIndex,
    required this.stepCount,
    required this.progress,
    required this.child,
  });

  final String churchLogo;
  final String churchName;
  final int stepIndex;
  final int stepCount;
  final double progress;
  final Widget child;

  @override
  State<_StepViewport> createState() => _StepViewportState();
}

class _StepViewportState extends State<_StepViewport> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        primary: false,
        padding: const EdgeInsets.only(right: 4),
        child: Column(
          children: [
            ChurchLogoAvatar(
              logo: widget.churchLogo,
              size: 84,
            ),
            const SizedBox(height: 14),
            _FlowHeader(
              title: widget.churchName,
              stepIndex: widget.stepIndex,
              stepCount: widget.stepCount,
              progress: widget.progress,
            ),
            const SizedBox(height: 16),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.rows,
  });

  final List<_ReviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...rows
            .where((row) => row.value.trim().isNotEmpty)
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ReviewRow {
  const _ReviewRow(this.label, this.value);

  final String label;
  final String value;
}
