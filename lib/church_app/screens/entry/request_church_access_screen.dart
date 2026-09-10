import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/self_signup_membership_helper.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart'
    show selectedChurchProvider;
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/app_entry.dart';
import 'package:flutter_application/church_app/screens/entry/request_pending_screen.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_errors.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_paths.dart';
import 'package:flutter_application/church_app/services/notification_service.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_profile_avatar.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';
import 'package:flutter_application/church_app/widgets/linear_screen_background_widget.dart';
import 'package:flutter_application/church_app/widgets/solid_button_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';

/// The self-service "request access" step (§5.5) for a person who already
/// has an identity doc (`users/{uid}`) — every signed-in, profile-complete
/// user reaching the guest shell or the church switcher. No fields are
/// re-collected: name/phone/dob/gender/etc. are read from [UserIdentity] and
/// sent to the same `requestAccess` write `login_request_screen.dart` uses
/// for its admin-created path, just without re-asking for any of it.
///
/// The full multi-step `LoginRequestScreen` remains the admin-create path
/// (`adminCreateMode: true`) — an admin-created member has no identity doc,
/// so the admin must supply everything (§9.3).
class RequestChurchAccessScreen extends ConsumerStatefulWidget {
  const RequestChurchAccessScreen({
    super.key,
    required this.churchId,
    required this.churchName,
    this.churchLogo = '',
  });

  final String churchId;
  final String churchName;
  final String churchLogo;

  @override
  ConsumerState<RequestChurchAccessScreen> createState() =>
      _RequestChurchAccessScreenState();
}

class _RequestChurchAccessScreenState
    extends ConsumerState<RequestChurchAccessScreen> {
  bool _submitting = false;

  Future<void> _submit(UserIdentity identity) async {
    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) return;

    setState(() => _submitting = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final existingDoc = await FirestorePaths.churchMemberDoc(
        firestore,
        widget.churchId,
        firebaseUser.uid,
      ).get();

      if (existingDoc.exists) {
        // Someone else already requested/joined between opening this screen
        // and tapping submit — never overwrite an existing row (§9.7).
        final alreadyApproved = existingDoc.data()?['approved'] == true;
        if (!mounted) return;
        if (alreadyApproved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('auth.already_requested'))),
          );
          await _enterChurch();
        } else {
          _goToPendingScreen(
            notifying: existingDoc.data()?['notifyOnApproval'] == true,
          );
        }
        return;
      }

      final category = deriveSelfSignupCategory(identity.maritalStatus);
      final familyId = resolveSelfSignupFamilyId(
        category: category,
        name: identity.name,
        churchId: widget.churchId,
      );

      var shouldAutoApprove = false;
      final normalizedEmail = identity.email.trim().toLowerCase();
      if (normalizedEmail.isNotEmpty) {
        // Only the church's sole listed admin can actually read these (via
        // isChurchAdmin's own internal, rules-unrestricted lookup) — for
        // every other requester (the common case: someone joining a church
        // they don't administer) this throws PERMISSION_DENIED, which must
        // not abort the request-access submission itself. Falling back to
        // "not auto-approved" is exactly correct for that caller anyway.
        try {
          final membersSnapshot = await FirestorePaths.churchMembers(
            firestore,
            widget.churchId,
          ).limit(1).get();
          final appConfigDoc = await FirestorePaths.churchAppConfig(
            firestore,
            widget.churchId,
          ).get();
          final admins =
              List<String>.from(appConfigDoc.data()?['admins'] ?? const [])
                  .map((item) => item.trim().toLowerCase())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false);
          shouldAutoApprove = membersSnapshot.docs.isEmpty &&
              admins.length == 1 &&
              admins.first == normalizedEmail;
        } catch (_) {
          shouldAutoApprove = false;
        }
      }

      await ref.read(authRepositoryProvider).requestAccess(
            name: identity.name,
            phone: identity.phone,
            contact: identity.phone,
            location: identity.location,
            address: identity.address,
            gender: identity.gender,
            category: category,
            familyId: familyId,
            dob: identity.dob ?? DateTime.now(),
            authToken: '',
            churchId: widget.churchId,
            maritalStatus: identity.maritalStatus,
            weddingDay: identity.weddingDay,
            educationalQualification: identity.educationalQualification,
            talentsAndGifts: identity.talentsAndGifts,
            approved: shouldAutoApprove,
          );

      if (!mounted) return;
      if (shouldAutoApprove) {
        await _enterChurch();
      } else {
        _goToPendingScreen(notifying: false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapFirebaseAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Only ever called for an approved membership. A pending one must never
  /// touch `selectedChurchProvider`/local storage/`lastActiveChurchId` —
  /// doing so unconditionally here previously let a still-pending request
  /// resolve straight into `ChurchTabScreen` whenever the person also had
  /// an approved membership elsewhere (found in testing; §9.1 — membership
  /// existing is never authorization on its own). Use [_returnToEntryGate]
  /// for the pending case instead.
  Future<void> _enterChurch() async {
    await ChurchLocalStorage().saveChurch(
      id: widget.churchId,
      name: widget.churchName,
      logo: widget.churchLogo,
    );
    if (!mounted) return;
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
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid != null) {
      unawaited(
        UserIdentityRepository(firestore: ref.read(firestoreProvider))
            .setLastActiveChurchId(uid, widget.churchId),
      );
    }
    unawaited(
      syncNotificationTopicIfAuthorized(
        ProviderScope.containerOf(context, listen: false),
      ),
    );
    if (!mounted) return;
    _returnToEntryGate();
  }

  void _goToPendingScreen({required bool notifying}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RequestPendingScreen(
          churchId: widget.churchId,
          churchName: widget.churchName,
          churchLogo: widget.churchLogo,
          initiallyNotifying: notifying,
        ),
      ),
    );
  }

  /// Re-enters the normal AppEntry gate without touching any church
  /// selection state — used both after entering an approved church and
  /// after a pending request, letting the gate decide (approved church,
  /// picker, or guest shell) purely from the person's actual memberships.
  void _returnToEntryGate() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppEntry()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(userIdentityProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AppBarTitle(text: context.t('auth.request_access')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: LinearScreenBackground(
        solidBackground: true,
        child: SafeArea(
          child: identityAsync.when(
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (_, __) =>
                Center(child: Text(context.t('guest_shell.churches_error'))),
            data: (identity) {
              if (identity == null) {
                return Center(
                  child: Text(context.t('guest_shell.churches_error')),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: ChurchLogoAvatar(
                        logo: widget.churchLogo,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.churchName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('auth.request_access_explainer'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          AppProfileAvatar(
                            name: identity.name,
                            imageUrl: identity.profilePhotoUrl.trim().isEmpty
                                ? null
                                : identity.profilePhotoUrl,
                            radius: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  identity.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (identity.email.trim().isNotEmpty)
                                  Text(
                                    identity.email,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (identity.phone.trim().isNotEmpty)
                                  Text(
                                    identity.phone,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SolidButton(
                      label: context.t('auth.request_access'),
                      isLoading: _submitting,
                      onPressed: _submitting ? null : () => _submit(identity),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
