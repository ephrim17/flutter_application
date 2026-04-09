import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
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
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/services/analytics/firebase_analytics_helper.dart';
import 'package:flutter_application/church_app/services/side_drawer/members_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/notification_reprompt_sheet.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';

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
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _educationalQualificationController = TextEditingController();
  final _talentsAndGiftsController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  final _membershipNotesController = TextEditingController();
  final _baptismChurchNameController = TextEditingController();
  final _baptismPastorNameController = TextEditingController();
  final _baptismCertificateNumberController = TextEditingController();
  final _marriageOtherChurchNameController = TextEditingController();

  int _stepIndex = 0;
  DateTime? _dob;
  DateTime? _weddingDay;
  DateTime? _baptismDate;
  String _gender = '';
  String _category = '';
  String _maritalStatus = '';
  bool _useExistingFamilyId = false;
  bool _financialSupportRequired = false;
  bool _solemnizedBaptism = false;
  String _marriageSolemnizationChurchType = '';
  String _membershipCurrentStatus = '';
  String? _selectedExistingFamilyId;
  int _financialStabilityRating = 0;
  Set<String> _selectedChurchGroupIds = <String>{};
  late final Future<List<String>> _familyIdsFuture;

  bool get _isEditMode => widget.existingMember != null;
  bool get _showAdminSections => widget.adminCreateMode || _isEditMode;
  int get _stepCount => _showAdminSections ? 4 : 2;

  @override
  void initState() {
    super.initState();
    _syncCategoryWithMaritalStatus();
    _familyIdsFuture =
        ref.read(authRepositoryProvider).getFamilyIds(widget.churchId);
    final existingMember = widget.existingMember;
    if (existingMember != null) {
      _nameController.text = existingMember.name;
      _phoneController.text = existingMember.phone;
      _contactController.text = existingMember.contact;
      _emailController.text = existingMember.email;
      _locationController.text = existingMember.location;
      _addressController.text = existingMember.address;
      _dob = existingMember.dob;
      _weddingDay = existingMember.weddingDay;
      _gender = existingMember.gender.trim().toLowerCase();
      _category = existingMember.category.trim().toLowerCase();
      _maritalStatus = existingMember.maritalStatus.trim().toLowerCase();
      _financialStabilityRating = existingMember.financialStabilityRating;
      _financialSupportRequired = existingMember.financialSupportRequired;
      _educationalQualificationController.text =
          existingMember.educationalQualification;
      _talentsAndGiftsController.text =
          existingMember.talentsAndGifts.join(', ');
      _additionalNotesController.text = existingMember.additionalNotes;
      _membershipNotesController.text = existingMember.membershipNotes;
      _solemnizedBaptism = existingMember.solemnizedBaptism;
      _baptismDate = existingMember.baptismDate;
      _baptismCertificateNumberController.text =
          existingMember.baptismCertificateNumber;
      _baptismChurchNameController.text = existingMember.baptismChurchName;
      _baptismPastorNameController.text = existingMember.baptismPastorName;
      _marriageSolemnizationChurchType =
          existingMember.marriageSolemnizationChurchType.trim();
      _marriageOtherChurchNameController.text =
          existingMember.marriageSolemnizationChurchName;
      _membershipCurrentStatus = existingMember.membershipCurrentStatus.trim();
      if (_maritalStatus == 'married' &&
          _marriageSolemnizationChurchType.isEmpty &&
          existingMember.marriageSolemnizationChurchName.trim().isNotEmpty) {
        _marriageSolemnizationChurchType =
            existingMember.marriageSolemnizationChurchName.trim() ==
                    widget.churchName.trim()
                ? 'current_church'
                : 'other_church';
      }
      _selectedChurchGroupIds = existingMember.churchGroupIds.toSet();

      if (_category == 'family') {
        _selectedExistingFamilyId = existingMember.familyId.trim().isEmpty
            ? null
            : existingMember.familyId.trim();
        _useExistingFamilyId = _selectedExistingFamilyId != null;
        _familyNameController.text =
            _familySeedFromId(existingMember.familyId.trim());
      }
      _syncCategoryWithMaritalStatus();
    } else if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _familyNameController.dispose();
    _educationalQualificationController.dispose();
    _talentsAndGiftsController.dispose();
    _additionalNotesController.dispose();
    _membershipNotesController.dispose();
    _baptismChurchNameController.dispose();
    _baptismPastorNameController.dispose();
    _baptismCertificateNumberController.dispose();
    _marriageOtherChurchNameController.dispose();
    super.dispose();
  }

  String _resolveFamilyId() {
    if (!_showAdminSections) {
      final seed = _nameController.text.trim();
      if (seed.isEmpty) return '';
      final normalizedSeed = _normalizeCategorySeed(seed);
      if (normalizedSeed.isEmpty) return '';
      return '${_category.toLowerCase()}_${normalizedSeed}_${widget.churchId}';
    }

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

  void _syncCategoryWithMaritalStatus() {
    _category = _maritalStatus == 'married' ? 'family' : 'individual';
    if (_category != 'family') {
      _useExistingFamilyId = false;
      _selectedExistingFamilyId = null;
      _familyNameController.clear();
    }
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

  int? _calculatedAge() {
    if (_dob == null) return null;
    final now = DateTime.now();
    var age = now.year - _dob!.year;
    final hasHadBirthdayThisYear = now.month > _dob!.month ||
        (now.month == _dob!.month && now.day >= _dob!.day);
    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }
    return age < 0 ? null : age;
  }

  List<String> _parsedTalentsAndGifts() {
    return _talentsAndGiftsController.text
        .split(RegExp(r'[,\\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) {
      return context.t('common.not_provided', fallback: 'Not provided');
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _dob ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _dob = pickedDate;
      });
    }
  }

  Future<void> _pickWeddingDay() async {
    FocusScope.of(context).unfocus();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _weddingDay ?? _dob ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _weddingDay = pickedDate;
      });
    }
  }

  Future<void> _pickBaptismDate() async {
    FocusScope.of(context).unfocus();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _baptismDate ?? _weddingDay ?? _dob ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _baptismDate = pickedDate;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String? _validateCurrentStep() {
    if (_showAdminSections) {
      switch (_stepIndex) {
        case 0:
          final name = _nameController.text.trim();
          final contact = _phoneController.text.trim();
          if (name.isEmpty) {
            return context.t(
              'members.member_name_required',
              fallback: 'Please enter the member name',
            );
          }
          if (name.length < 3) {
            return context.t(
              'auth.name_min_length',
              fallback: 'Name must be at least 3 characters',
            );
          }
          final phoneRegex = RegExp(r'^[6-9]\d{9}$');
          if (!phoneRegex.hasMatch(contact)) {
            return context.t(
              'auth.phone_invalid',
              fallback: 'Enter a valid 10-digit phone number',
            );
          }
          if (_addressController.text.trim().isEmpty) {
            return context.t(
              'members.member_address_required',
              fallback: 'Please enter the member address',
            );
          }
          return null;
        case 1:
          if (_maritalStatus == 'married' && _weddingDay == null) {
            return context.t(
              'members.member_wedding_day_required',
              fallback: 'Please select the wedding day',
            );
          }
          if (_gender.isEmpty) {
            return context.t(
              'members.member_gender_required',
              fallback: 'Please select the member gender',
            );
          }
          if (_dob == null) {
            return context.t(
              'members.member_dob_required',
              fallback: 'Please select the member date of birth',
            );
          }
          if (_category == 'family') {
            if (_useExistingFamilyId &&
                (_selectedExistingFamilyId == null ||
                    _selectedExistingFamilyId!.trim().isEmpty)) {
              return 'Please select or create a family ID';
            }
            if (!_useExistingFamilyId &&
                _familyNameController.text.trim().isEmpty) {
              return 'Please enter a family name';
            }
          }
          return null;
        case 2:
          if (_solemnizedBaptism && _baptismDate == null) {
            return context.t(
              'members.baptism_date_required',
              fallback: 'Please select the baptism date',
            );
          }
          if (_solemnizedBaptism &&
              _baptismChurchNameController.text.trim().isEmpty) {
            return context.t(
              'members.baptism_church_name_required',
              fallback: 'Please enter the baptism church name',
            );
          }
          if (_solemnizedBaptism &&
              _baptismPastorNameController.text.trim().isEmpty) {
            return context.t(
              'members.baptism_pastor_name_required',
              fallback: 'Please enter the baptism pastor name',
            );
          }
          if (_maritalStatus == 'married' &&
              _marriageSolemnizationChurchType.isEmpty) {
            return context.t(
              'members.marriage_solemnization_required',
              fallback: 'Please choose the marriage solemnization church',
            );
          }
          if (_maritalStatus == 'married' &&
              _marriageSolemnizationChurchType == 'other_church' &&
              _marriageOtherChurchNameController.text.trim().isEmpty) {
            return context.t(
              'members.marriage_solemnization_other_church_required',
              fallback: 'Please enter the other church name',
            );
          }
          return null;
        default:
          return null;
      }
    }

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
        if (_addressController.text.trim().isEmpty) {
          return context.t(
            'auth.address_required',
            fallback: 'Please enter your address',
          );
        }
        if (_maritalStatus.isEmpty) {
          return context.t(
            'members.marital_status_required',
            fallback: 'Please select your marital status',
          );
        }
        if (_maritalStatus == 'married' && _weddingDay == null) {
          return context.t(
            'members.wedding_day_required',
            fallback: 'Please select your wedding day',
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
        SnackBar(
          content: Text(
            context.t(
              'members.account_required_before_request',
              fallback: 'Create your account first before requesting access.',
            ),
          ),
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
          contact: _showAdminSections
              ? _phoneController.text.trim()
              : _contactController.text.trim(),
          location: _locationController.text.trim(),
          address: _addressController.text.trim(),
          gender: _gender,
          category: _category,
          familyId: familyId,
          dob: _dob!,
          maritalStatus: _maritalStatus,
          weddingDay: _weddingDay,
          financialStabilityRating: _financialStabilityRating,
          financialSupportRequired: _financialSupportRequired,
          educationalQualification:
              _educationalQualificationController.text.trim(),
          talentsAndGifts: _parsedTalentsAndGifts(),
          churchGroupIds: _selectedChurchGroupIds.toList(),
          solemnizedBaptism: _solemnizedBaptism,
          baptismDate: _baptismDate,
          baptismCertificateNumber:
              _baptismCertificateNumberController.text.trim(),
          baptismChurchName: _baptismChurchNameController.text.trim(),
          baptismPastorName: _baptismPastorNameController.text.trim(),
          marriageSolemnizationChurchType: _marriageSolemnizationChurchType,
          marriageSolemnizationChurchName:
              _marriageSolemnizationChurchType == 'current_church'
                  ? widget.churchName
                  : _marriageOtherChurchNameController.text.trim(),
          membershipCurrentStatus: _membershipCurrentStatus,
          membershipNotes: _membershipNotesController.text.trim(),
          additionalNotes: _additionalNotesController.text.trim(),
          familyLabel: _category == 'family' && !_useExistingFamilyId
              ? _familyNameController.text.trim()
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'members.member_updated_success',
                fallback: 'Member updated successfully.',
              ),
            ),
          ),
        );
        await logAnalyticsEvent(
          name: 'member_updated',
          parameters: {
            'church_id': widget.churchId,
            'member_id': widget.existingMember?.uid ?? widget.targetUid,
          },
        );
        Navigator.of(context).pop();
        return;
      }

      if (!widget.adminCreateMode) {
        final existingDoc =
            await ref.read(authRepositoryProvider).getChurchUserDoc(
                  churchId: widget.churchId,
                  uid: firebaseUser!.uid,
                );

        if (existingDoc.exists) {
          final appUser = AppUser.fromFirestore(
            existingDoc.id,
            existingDoc.data() as Map<String, dynamic>,
          );
          ref.read(forcePreflowThemeProvider.notifier).state =
              !appUser.approved;

          ref.read(selectedChurchProvider.notifier).state = Church(
            id: widget.churchId,
            name: widget.churchName,
            address: '',
            contact: '',
            email: '',
            pastorName: '',
            pastorPhoto: '',
            logo: widget.churchLogo,
            enabled: true,
            registrationSource: 'super_admin',
          );
          ref.invalidate(currentChurchIdProvider);
          unawaited(
            syncNotificationTopicIfAuthorized(
              ProviderScope.containerOf(context, listen: false),
            ),
          );

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

      final normalizedEmail = (widget.initialEmail ??
              firebaseUser?.email ??
              _emailController.text.trim())
          .trim()
          .toLowerCase();
      var shouldAutoApprove = widget.adminCreateMode;

      if (!widget.adminCreateMode && normalizedEmail.isNotEmpty) {
        final usersSnapshot = await FirestorePaths.churchUsers(
          ref.read(firestoreProvider),
          widget.churchId,
        ).limit(1).get();
        final appConfigDoc = await FirestorePaths.churchAppConfig(
          ref.read(firestoreProvider),
          widget.churchId,
        ).get();
        final admins =
            List<String>.from(appConfigDoc.data()?['admins'] ?? const [])
                .map((item) => item.trim().toLowerCase())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);

        shouldAutoApprove = usersSnapshot.docs.isEmpty &&
            admins.length == 1 &&
            admins.first == normalizedEmail;
      }

      await ref.read(authRepositoryProvider).requestAccess(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            contact: _showAdminSections
                ? _phoneController.text.trim()
                : _contactController.text.trim(),
            location: _locationController.text.trim(),
            address: _addressController.text.trim(),
            gender: _gender,
            category: _category,
            familyId: familyId,
            dob: _dob!,
            authToken: authToken,
            churchId: widget.churchId,
            maritalStatus: _maritalStatus,
            weddingDay: _weddingDay,
            financialStabilityRating: _financialStabilityRating,
            financialSupportRequired: _financialSupportRequired,
            educationalQualification:
                _educationalQualificationController.text.trim(),
            talentsAndGifts: _parsedTalentsAndGifts(),
            churchGroupIds: _selectedChurchGroupIds.toList(),
            solemnizedBaptism: _solemnizedBaptism,
            baptismDate: _baptismDate,
            baptismCertificateNumber:
                _baptismCertificateNumberController.text.trim(),
            baptismChurchName: _baptismChurchNameController.text.trim(),
            baptismPastorName: _baptismPastorNameController.text.trim(),
            marriageSolemnizationChurchType: _marriageSolemnizationChurchType,
            marriageSolemnizationChurchName:
                _marriageSolemnizationChurchType == 'current_church'
                    ? widget.churchName
                    : _marriageOtherChurchNameController.text.trim(),
            membershipCurrentStatus: _membershipCurrentStatus,
            membershipNotes: _membershipNotesController.text.trim(),
            additionalNotes: _additionalNotesController.text.trim(),
            familyLabel: _category == 'family' && !_useExistingFamilyId
                ? _familyNameController.text.trim()
                : null,
            targetUid: widget.targetUid,
            targetEmail: widget.initialEmail,
            approved: shouldAutoApprove,
            createChurchMemberWithoutAuth:
                widget.adminCreateMode && widget.targetUid == null,
          );

      if (widget.adminCreateMode) {
        await logAnalyticsEvent(
          name: 'member_created',
          parameters: {
            'church_id': widget.churchId,
            'member_id': widget.targetUid ?? firebaseUser?.uid,
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                'members.member_created_success',
                fallback: 'Member created successfully.',
              ),
            ),
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
        pastorPhoto: '',
        logo: widget.churchLogo,
        enabled: true,
        registrationSource: 'super_admin',
      );
      ref.invalidate(currentChurchIdProvider);
      ref.read(forcePreflowThemeProvider.notifier).state = !shouldAutoApprove;
      unawaited(
        syncNotificationTopicIfAuthorized(
          ProviderScope.containerOf(context, listen: false),
        ),
      );

      if (!mounted) return;
      final createdUser = AppUser(
        uid: firebaseUser!.uid,
        name: _nameController.text.trim(),
        email: normalizedEmail,
        role: 'user',
        approved: shouldAutoApprove,
        phone: _phoneController.text.trim(),
        contact: _showAdminSections
            ? _phoneController.text.trim()
            : _contactController.text.trim(),
        location: _locationController.text.trim(),
        address: _addressController.text.trim(),
        gender: _gender,
        category: _category,
        familyId: familyId,
        maritalStatus: _maritalStatus,
        weddingDay: _weddingDay,
        financialStabilityRating: _financialStabilityRating,
        financialSupportRequired: _financialSupportRequired,
        educationalQualification:
            _educationalQualificationController.text.trim(),
        talentsAndGifts: _parsedTalentsAndGifts(),
        churchGroupIds: _selectedChurchGroupIds.toList(),
        authToken: authToken,
        dob: _dob!,
        solemnizedBaptism: _solemnizedBaptism,
        baptismDate: _baptismDate,
        baptismCertificateNumber:
            _baptismCertificateNumberController.text.trim(),
        baptismChurchName: _baptismChurchNameController.text.trim(),
        baptismPastorName: _baptismPastorNameController.text.trim(),
        marriageSolemnizationChurchType: _marriageSolemnizationChurchType,
        marriageSolemnizationChurchName:
            _marriageSolemnizationChurchType == 'current_church'
                ? widget.churchName
                : _marriageOtherChurchNameController.text.trim(),
        membershipCurrentStatus: _membershipCurrentStatus,
        membershipNotes: _membershipNotesController.text.trim(),
        additionalNotes: _additionalNotesController.text.trim(),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AppEntry(initialUser: createdUser),
        ),
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
                  ? context.t('members.create_member',
                      fallback: 'Create Member')
                  : context.t('auth.request_access',
                      fallback: 'Request Access'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        solidBackground: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _showAdminSections
                        ? [
                            _StepViewport(
                              churchLogo: widget.churchLogo,
                              churchName: widget.churchName,
                              stepIndex: _stepIndex,
                              stepCount: _stepCount,
                              progress: progress,
                              child: _StepShell(
                                title: context.t(
                                  'members.basic_details_title',
                                  fallback: 'Basic Details',
                                ),
                                subtitle: context.t(
                                  'members.basic_details_subtitle',
                                  fallback:
                                      'Capture the member information in one place.',
                                ),
                                child: Column(
                                  children: [
                                    if (_isEditMode) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.38),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.16),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.history_rounded,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.t(
                                                      'members.member_since_label',
                                                      fallback: 'Member Since',
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatMemberSince(
                                                      widget.existingMember
                                                          ?.createdAt,
                                                    ),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    AppTextField(
                                      controller: _nameController,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.name_label',
                                          fallback: 'Name',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      onTap: _pickDob,
                                      child: InputDecorator(
                                        decoration: appTextFieldDecoration(
                                          context,
                                          labelText: context.t(
                                            'auth.dob_label',
                                            fallback: 'Date of Birth',
                                          ),
                                          suffixIcon:
                                              const Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          _dob == null
                                              ? context.t(
                                                  'auth.dob_select',
                                                  fallback:
                                                      'Select date of birth',
                                                )
                                              : '${_dob!.day.toString().padLeft(2, '0')}/'
                                                  '${_dob!.month.toString().padLeft(2, '0')}/'
                                                  '${_dob!.year}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InputDecorator(
                                      decoration: appTextFieldDecoration(
                                        context,
                                        labelText: context.t(
                                          'auth.age_label',
                                          fallback: 'Age',
                                        ),
                                      ),
                                      child: Text(
                                        _calculatedAge()?.toString() ??
                                            context.t(
                                              'auth.age_hint',
                                              fallback:
                                                  'Select DOB to calculate age',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppDropdownField<String>(
                                      initialValue:
                                          _gender.isEmpty ? null : _gender,
                                      labelText: context.t(
                                        'members.gender_label',
                                        fallback: 'Gender',
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text(
                                            context.t(
                                              'common.male',
                                              fallback: 'Male',
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text(
                                            context.t(
                                              'common.female',
                                              fallback: 'Female',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _gender = value ?? '';
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.contact_label',
                                          fallback: 'Contact',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _addressController,
                                      keyboardType: TextInputType.streetAddress,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.address_label',
                                          fallback: 'Address',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppDropdownField<String>(
                                      initialValue: _maritalStatus.isEmpty
                                          ? null
                                          : _maritalStatus,
                                      labelText: context.t(
                                        'members.marital_status_label',
                                        fallback: 'Marital Status',
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'individual',
                                          child: Text(
                                            context.t(
                                              'common.individual',
                                              fallback: 'Individual',
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'married',
                                          child: Text(
                                            context.t(
                                              'common.married',
                                              fallback: 'Married',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _maritalStatus = value ?? '';
                                          _syncCategoryWithMaritalStatus();
                                          if (_maritalStatus != 'married') {
                                            _weddingDay = null;
                                            _marriageSolemnizationChurchType =
                                                '';
                                            _marriageOtherChurchNameController
                                                .clear();
                                          }
                                        });
                                      },
                                    ),
                                    if (_maritalStatus == 'married') ...[
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: _pickWeddingDay,
                                        child: InputDecorator(
                                          decoration: appTextFieldDecoration(
                                            context,
                                            labelText: context.t(
                                              'members.wedding_day_label',
                                              fallback: 'Wedding Day',
                                            ),
                                            suffixIcon: const Icon(
                                              Icons.calendar_today,
                                            ),
                                          ),
                                          child: Text(
                                            _weddingDay == null
                                                ? context.t(
                                                    'members.wedding_day_hint',
                                                    fallback:
                                                        'Select wedding day',
                                                  )
                                                : '${_weddingDay!.day.toString().padLeft(2, '0')}/'
                                                    '${_weddingDay!.month.toString().padLeft(2, '0')}/'
                                                    '${_weddingDay!.year}',
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_category == 'family') ...[
                                      const SizedBox(height: 16),
                                      FutureBuilder<List<String>>(
                                        future: _familyIdsFuture,
                                        builder: (context, snapshot) {
                                          final familyIds =
                                              snapshot.data ?? const <String>[];
                                          final selectedFamilyValue =
                                              familyIds.contains(
                                                      _selectedExistingFamilyId)
                                                  ? _selectedExistingFamilyId
                                                  : null;

                                          return Column(
                                            children: [
                                              if (familyIds.isNotEmpty)
                                                SwitchListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    context.t(
                                                      'auth.family_existing_toggle',
                                                      fallback:
                                                          'Use existing family ID',
                                                    ),
                                                  ),
                                                  value: _useExistingFamilyId,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _useExistingFamilyId =
                                                          value;
                                                      if (!value) {
                                                        _selectedExistingFamilyId =
                                                            null;
                                                      }
                                                    });
                                                  },
                                                ),
                                              const SizedBox(height: 8),
                                              if (familyIds.isNotEmpty &&
                                                  _useExistingFamilyId)
                                                AppDropdownField<String>(
                                                  initialValue:
                                                      selectedFamilyValue,
                                                  labelText: context.t(
                                                    'members.family_id_label',
                                                    fallback: 'Family ID',
                                                  ),
                                                  items: familyIds
                                                      .map(
                                                        (familyId) =>
                                                            DropdownMenuItem(
                                                          value: familyId,
                                                          child: Text(
                                                            _formatFamilyOptionLabel(
                                                              familyId,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedExistingFamilyId =
                                                          value;
                                                    });
                                                  },
                                                )
                                              else
                                                AppTextField(
                                                  controller:
                                                      _familyNameController,
                                                  decoration: InputDecoration(
                                                    labelText: context.t(
                                                      'members.family_name_label',
                                                      fallback: 'Family Name',
                                                    ),
                                                    helperText: context.t(
                                                      'auth.family_name_helper',
                                                      fallback:
                                                          'Used to generate a family ID',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
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
                                title: context.t(
                                  'members.extended_information_title',
                                  fallback: 'Extended Information',
                                ),
                                subtitle: context.t(
                                  'members.extended_information_subtitle',
                                  fallback:
                                      'Capture financial, educational and gifting details.',
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.38),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.16),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.notes_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              context.t(
                                                'members.extended_information_note',
                                                fallback:
                                                    'Use this section for details that help the church understand care needs, education, and gifting better.',
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                    height: 1.35,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        context
                                            .t(
                                              'members.financial_stability_rating',
                                              fallback:
                                                  'Financial Stability Rating: {rating}/5',
                                            )
                                            .replaceAll(
                                              '{rating}',
                                              _financialStabilityRating
                                                  .toString(),
                                            ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    Slider(
                                      value:
                                          _financialStabilityRating.toDouble(),
                                      min: 0,
                                      max: 5,
                                      divisions: 5,
                                      label: '$_financialStabilityRating',
                                      onChanged: (value) {
                                        setState(() {
                                          _financialStabilityRating =
                                              value.round();
                                        });
                                      },
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        context.t(
                                          'members.financial_support_required',
                                          fallback:
                                              'Financial Support Required',
                                        ),
                                      ),
                                      value: _financialSupportRequired,
                                      onChanged: (value) {
                                        setState(() {
                                          _financialSupportRequired = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    AppTextField(
                                      controller:
                                          _educationalQualificationController,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.educational_qualification',
                                          fallback: 'Educational Qualification',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _talentsAndGiftsController,
                                      minLines: 2,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.talents_and_gifts',
                                          fallback: 'Talents & Gifts',
                                        ),
                                        helperText: context.t(
                                          'members.talents_and_gifts_helper',
                                          fallback:
                                              'Add comma-separated talents or gifts',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _additionalNotesController,
                                      minLines: 2,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.additional_notes_label',
                                          fallback: 'Additional Notes',
                                        ),
                                        helperText: context.t(
                                          'members.additional_notes_helper',
                                          fallback:
                                              'Optional short notes about this member for church reference.',
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
                                title: context.t(
                                  'members.church_records_title',
                                  fallback: 'Church Records',
                                ),
                                subtitle: context.t(
                                  'members.church_records_subtitle',
                                  fallback:
                                      'Capture baptism, marriage solemnization, and membership records for this member.',
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppDropdownField<String>(
                                      initialValue:
                                          _solemnizedBaptism ? 'yes' : 'no',
                                      labelText: context.t(
                                        'members.solemnized_baptism_label',
                                        fallback: 'Solemnized Baptism',
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'yes',
                                          child: Text(
                                            context.t(
                                              'common.yes',
                                              fallback: 'Yes',
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'no',
                                          child: Text(
                                            context.t(
                                              'common.no',
                                              fallback: 'No',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _solemnizedBaptism = value == 'yes';
                                          if (!_solemnizedBaptism) {
                                            _baptismDate = null;
                                            _baptismCertificateNumberController
                                                .clear();
                                            _baptismChurchNameController
                                                .clear();
                                            _baptismPastorNameController
                                                .clear();
                                          }
                                        });
                                      },
                                    ),
                                    if (_solemnizedBaptism) ...[
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: _pickBaptismDate,
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: context.t(
                                              'members.baptism_date_label',
                                              fallback: 'Baptism Date',
                                            ),
                                            suffixIcon: const Icon(
                                                Icons.calendar_today),
                                          ),
                                          child: Text(
                                            _formatDate(_baptismDate).isEmpty
                                                ? context.t(
                                                    'members.baptism_date_hint',
                                                    fallback:
                                                        'Select baptism date',
                                                  )
                                                : _formatDate(_baptismDate),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      AppTextField(
                                        controller:
                                            _baptismCertificateNumberController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: context.t(
                                            'members.baptism_certificate_number_label',
                                            fallback:
                                                'Baptism Certificate Number',
                                          ),
                                          helperText: context.t(
                                            'members.baptism_certificate_number_helper',
                                            fallback: 'Optional',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      AppTextField(
                                        controller:
                                            _baptismChurchNameController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: context.t(
                                            'members.baptism_church_name_label',
                                            fallback: 'Church Name',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      AppTextField(
                                        controller:
                                            _baptismPastorNameController,
                                        decoration: InputDecoration(
                                          labelText: context.t(
                                            'members.baptism_pastor_name_label',
                                            fallback: 'Pastor Name',
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_maritalStatus == 'married') ...[
                                      const SizedBox(height: 24),
                                      Text(
                                        context.t(
                                          'members.marriage_solemnization_title',
                                          fallback: 'Marriage Solemnization',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      AppDropdownField<String>(
                                        initialValue:
                                            _marriageSolemnizationChurchType
                                                    .isEmpty
                                                ? null
                                                : _marriageSolemnizationChurchType,
                                        labelText: context.t(
                                          'members.marriage_solemnization_church_label',
                                          fallback: 'Select Church',
                                        ),
                                        items: [
                                          DropdownMenuItem(
                                            value: 'current_church',
                                            child: Text(
                                              context.t(
                                                'members.current_church_option',
                                                fallback: 'Current Church',
                                              ),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'other_church',
                                            child: Text(
                                              context.t(
                                                'members.other_church_option',
                                                fallback:
                                                    'Type Other Church Name',
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _marriageSolemnizationChurchType =
                                                value ?? '';
                                            if (_marriageSolemnizationChurchType !=
                                                'other_church') {
                                              _marriageOtherChurchNameController
                                                  .clear();
                                            }
                                          });
                                        },
                                      ),
                                      if (_marriageSolemnizationChurchType ==
                                          'current_church') ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.32),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            widget.churchName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                      if (_marriageSolemnizationChurchType ==
                                          'other_church') ...[
                                        const SizedBox(height: 16),
                                        AppTextField(
                                          controller:
                                              _marriageOtherChurchNameController,
                                          decoration: InputDecoration(
                                            labelText: context.t(
                                              'members.other_church_name_label',
                                              fallback: 'Other Church Name',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 24),
                                    Text(
                                      context.t(
                                        'members.membership_section_title',
                                        fallback: 'Membership Section',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    AppDropdownField<String>(
                                      initialValue:
                                          _membershipCurrentStatus.isEmpty
                                              ? null
                                              : _membershipCurrentStatus,
                                      labelText: context.t(
                                        'members.membership_current_status_label',
                                        fallback: 'Membership Current Status',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'active',
                                          child: Text('Active'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'transfered',
                                          child: Text('Transfered'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'quit_the_church',
                                          child: Text('Quit the church'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'not_known',
                                          child: Text('Not Known'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _membershipCurrentStatus =
                                              value ?? '';
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _membershipNotesController,
                                      minLines: 2,
                                      maxLines: 4,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'members.membership_notes_label',
                                          fallback: 'Additional Note',
                                        ),
                                        helperText: context.t(
                                          'members.membership_notes_helper',
                                          fallback:
                                              'Optional church membership note for reference.',
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
                                title: context.t(
                                  'members.church_groups_title',
                                  fallback: 'Church Groups',
                                ),
                                subtitle: context.t(
                                  'members.church_groups_subtitle',
                                  fallback:
                                      'Select the ministries and teams this member belongs to.',
                                ),
                                child: Column(
                                  children: [
                                    ...churchGroupDefinitions.map(
                                      (group) => CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(group.label),
                                        value: _selectedChurchGroupIds
                                            .contains(group.id),
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedChurchGroupIds
                                                  .add(group.id);
                                            } else {
                                              _selectedChurchGroupIds
                                                  .remove(group.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        : [
                            _StepViewport(
                              churchLogo: widget.churchLogo,
                              churchName: widget.churchName,
                              stepIndex: _stepIndex,
                              stepCount: _stepCount,
                              progress: progress,
                              child: _StepShell(
                                title: context.t(
                                  'members.basic_details_title',
                                  fallback: 'Basic Details',
                                ),
                                subtitle: context.t(
                                  'members.request_basic_details_subtitle',
                                  fallback:
                                      'Capture your basic details before submitting your request.',
                                ),
                                child: Column(
                                  children: [
                                    AppTextField(
                                      controller: _nameController,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'auth.name_label',
                                          fallback: 'Your Name',
                                        ),
                                        helperText: context.t(
                                          'auth.name_helper',
                                          fallback:
                                              'Name should have only characters, not numbers',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InkWell(
                                      onTap: _pickDob,
                                      child: InputDecorator(
                                        decoration: appTextFieldDecoration(
                                          context,
                                          labelText: context.t(
                                            'auth.dob_label',
                                            fallback: 'Date of Birth',
                                          ),
                                          suffixIcon:
                                              const Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          _dob == null
                                              ? context.t(
                                                  'auth.dob_hint',
                                                  fallback:
                                                      'Select your date of birth',
                                                )
                                              : '${_dob!.day.toString().padLeft(2, '0')}/'
                                                  '${_dob!.month.toString().padLeft(2, '0')}/'
                                                  '${_dob!.year}',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    InputDecorator(
                                      decoration: appTextFieldDecoration(
                                        context,
                                        labelText: context.t(
                                          'auth.age_label',
                                          fallback: 'Age',
                                        ),
                                      ),
                                      child: Text(
                                        _calculatedAge()?.toString() ??
                                            context.t(
                                              'auth.age_hint',
                                              fallback:
                                                  'Select DOB to calculate age',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppDropdownField<String>(
                                      initialValue:
                                          _gender.isEmpty ? null : _gender,
                                      labelText: context.t(
                                        'auth.gender_label',
                                        fallback: 'Gender',
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text(
                                            context.t(
                                              'common.male',
                                              fallback: 'Male',
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text(
                                            context.t(
                                              'common.female',
                                              fallback: 'Female',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _gender = value ?? '';
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: context.t('auth.phone_label',
                                            fallback: 'Contact'),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppTextField(
                                      controller: _addressController,
                                      keyboardType: TextInputType.streetAddress,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: context.t(
                                          'auth.address_label',
                                          fallback: 'Address',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    AppDropdownField<String>(
                                      initialValue: _maritalStatus.isEmpty
                                          ? null
                                          : _maritalStatus,
                                      labelText: context.t(
                                        'members.marital_status_label',
                                        fallback: 'Marital Status',
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'individual',
                                          child: Text(
                                            context.t(
                                              'common.individual',
                                              fallback: 'Individual',
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'married',
                                          child: Text(
                                            context.t(
                                              'common.married',
                                              fallback: 'Married',
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _maritalStatus = value ?? '';
                                          _syncCategoryWithMaritalStatus();
                                          if (_maritalStatus != 'married') {
                                            _weddingDay = null;
                                            _marriageSolemnizationChurchType =
                                                '';
                                            _marriageOtherChurchNameController
                                                .clear();
                                          }
                                        });
                                      },
                                    ),
                                    if (_maritalStatus == 'married') ...[
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: _pickWeddingDay,
                                        child: InputDecorator(
                                          decoration: appTextFieldDecoration(
                                            context,
                                            labelText: context.t(
                                              'members.wedding_day_label',
                                              fallback: 'Wedding Day',
                                            ),
                                            suffixIcon: const Icon(
                                              Icons.calendar_today,
                                            ),
                                          ),
                                          child: Text(
                                            _weddingDay == null
                                                ? context.t(
                                                    'members.wedding_day_hint',
                                                    fallback:
                                                        'Select wedding day',
                                                  )
                                                : '${_weddingDay!.day.toString().padLeft(2, '0')}/'
                                                    '${_weddingDay!.month.toString().padLeft(2, '0')}/'
                                                    '${_weddingDay!.year}',
                                          ),
                                        ),
                                      ),
                                    ],
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
                                title: context.t(
                                  'members.review_title',
                                  fallback: 'Review',
                                ),
                                subtitle: context.t(
                                  'members.review_subtitle',
                                  fallback:
                                      'Check the details before submitting your request.',
                                ),
                                child: _ReviewCard(
                                  rows: [
                                    _ReviewRow(
                                      context.t(
                                        'members.name_label',
                                        fallback: 'Name',
                                      ),
                                      _nameController.text.trim(),
                                    ),
                                    _ReviewRow(
                                      context.t(
                                        'members.contact_label',
                                        fallback: 'Contact',
                                      ),
                                      _phoneController.text.trim(),
                                    ),
                                    _ReviewRow(
                                      context.t(
                                        'members.gender_label',
                                        fallback: 'Gender',
                                      ),
                                      _gender,
                                    ),
                                    _ReviewRow(
                                      context.t(
                                        'members.date_of_birth_label',
                                        fallback: 'Date of Birth',
                                      ),
                                      _dob == null
                                          ? ''
                                          : '${_dob!.day.toString().padLeft(2, '0')}/'
                                              '${_dob!.month.toString().padLeft(2, '0')}/'
                                              '${_dob!.year}',
                                    ),
                                    _ReviewRow(
                                      context.t(
                                        'members.marital_status_label',
                                        fallback: 'Marital Status',
                                      ),
                                      _maritalStatus,
                                    ),
                                    if (_maritalStatus == 'married')
                                      _ReviewRow(
                                        context.t(
                                          'members.wedding_day_label',
                                          fallback: 'Wedding Day',
                                        ),
                                        _weddingDay == null
                                            ? ''
                                            : '${_weddingDay!.day.toString().padLeft(2, '0')}/'
                                                '${_weddingDay!.month.toString().padLeft(2, '0')}/'
                                                '${_weddingDay!.year}',
                                      ),
                                    _ReviewRow(
                                      context.t(
                                        'members.address_label',
                                        fallback: 'Address',
                                      ),
                                      _addressController.text.trim(),
                                    ),
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
                    const SizedBox(
                      height: 30,
                    )
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
          Text(
            '${context.t('common.step', fallback: 'Step')} ${stepIndex + 1} ${context.t('common.of', fallback: 'of')} $stepCount',
          ),
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
        ...rows.where((row) => row.value.trim().isNotEmpty).map(
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
