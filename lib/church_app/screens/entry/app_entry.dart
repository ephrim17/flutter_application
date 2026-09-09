import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/selected_church_local_storage.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/user_identity_model.dart';
import 'package:flutter_application/church_app/providers/app_config_provider.dart';
import 'package:flutter_application/church_app/providers/authentication/super_admin_provider.dart';
import 'package:flutter_application/church_app/providers/church_provider.dart';
import 'package:flutter_application/church_app/providers/preflow_theme_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:flutter_application/church_app/screens/entry/admin_mode_screen.dart';
import 'package:flutter_application/church_app/screens/entry/complete_profile_screen.dart';
import 'package:flutter_application/church_app/screens/entry/create_auth_account_screen.dart';
import 'package:flutter_application/church_app/screens/church_tab_screen.dart';
import 'package:flutter_application/church_app/screens/onboarding_screen.dart';
import 'package:flutter_application/church_app/screens/personal/guest_shell_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_home_screen.dart';
import 'package:flutter_application/church_app/screens/super_admin/super_admin_mode_screen.dart';
import 'package:flutter_application/church_app/services/user_identity_repository.dart';
import 'package:flutter_application/church_app/widgets/app_splash_screen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry state machine — KT Files/architecture/
/// user-church-decoupling-migration.md §5.4:
///   onboarding incomplete           -> onboarding
///   signed out                      -> auth
///   signed in, no identity doc      -> complete profile   (NEW)
///   super admin                     -> mode chooser
///   signed in, no approved anywhere -> guest shell         (NEW)
///   approved                        -> ChurchTabScreen
class AppEntry extends ConsumerStatefulWidget {
  const AppEntry({super.key});

  @override
  ConsumerState<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<AppEntry> {
  bool? _showOnboarding;

  void _syncSuperAdminSessionForUser(String uid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(superAdminEntryModeProvider.notifier).syncForUser(uid);
    });
  }

  void _syncPreflowTheme(bool enabled) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(forcePreflowThemeProvider.notifier);
      if (notifier.state != enabled) {
        notifier.state = enabled;
      }
    });
  }

  /// Picks a church to enter when nothing is currently selected — the
  /// common first-login-on-this-device case, where local storage has
  /// nothing to restore. Order: local storage (this device's last pick) ->
  /// `identity.lastActiveChurchId` (this person's last pick on any device)
  /// -> the earliest-joined approved membership, so `hasApprovedMembership`
  /// being true always actually lands on a real church instead of leaving
  /// `selectedChurchProvider` null underneath `ChurchTabScreen` (every
  /// section there depends on a resolved church id — left null, they all
  /// hang loading forever rather than erroring).
  void _restoreSelectedChurchIfNeeded(
    UserIdentity identity,
    List<ChurchMembership> approvedMemberships,
  ) {
    final selectedChurch = ref.watch(selectedChurchProvider);
    if (selectedChurch != null) return;
    if (approvedMemberships.isEmpty) return;

    final approvedChurchIds = approvedMemberships
        .map((membership) => membership.churchId)
        .toSet();
    final localChurchId = ref.watch(currentChurchIdProvider).value;

    String churchId;
    if (localChurchId != null &&
        approvedChurchIds.contains(localChurchId)) {
      churchId = localChurchId;
    } else if (identity.lastActiveChurchId != null &&
        approvedChurchIds.contains(identity.lastActiveChurchId)) {
      churchId = identity.lastActiveChurchId!;
    } else {
      final sorted = [...approvedMemberships]..sort((a, b) {
        final aJoined = a.joinedAt;
        final bJoined = b.joinedAt;
        if (aJoined == null || bJoined == null) return 0;
        return aJoined.compareTo(bJoined);
      });
      churchId = sorted.first.churchId;
    }

    final churchAsync = ref.watch(churchByIdProvider(churchId));
    final church = churchAsync.value;
    if (church == null) return;

    final uid = ref.watch(authStateProvider).value?.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(selectedChurchProvider.notifier);
      if (notifier.state != null) return;
      notifier.state = church;
      await ChurchLocalStorage().saveChurch(
        id: church.id,
        name: church.name,
        logo: church.logo,
      );
      if (uid != null) {
        unawaited(
          UserIdentityRepository(firestore: ref.read(firestoreProvider))
              .setLastActiveChurchId(uid, church.id),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) return;
    setState(() {
      _showOnboarding = !completed;
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while onboarding check is pending
    if (_showOnboarding == null) {
      return const Scaffold(
        body: Center(child: AppSplashScreen()),
      );
    }
    // Show onboarding if not completed
    if (_showOnboarding!) {
      _syncPreflowTheme(true);
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    final isSuperAdminAsync = ref.watch(isSuperAdminProvider);
    final identityAsync = ref.watch(userIdentityProvider);
    final superAdminSession = ref.watch(superAdminEntryModeProvider);
    final firebaseUser = ref.watch(authStateProvider).value;
    final isSuperAdmin = firebaseUser != null &&
        isSuperAdminAsync.maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

    if (firebaseUser != null && isSuperAdminAsync.isLoading) {
      return const Scaffold(
        body: Center(child: AppSplashScreen()),
      );
    }

    if (isSuperAdmin) {
      if (superAdminSession.isLoading) {
        return const Scaffold(
          body: Center(child: AppSplashScreen()),
        );
      }
      if (superAdminSession.uid != firebaseUser.uid) {
        _syncSuperAdminSessionForUser(firebaseUser.uid);
        return const Scaffold(
          body: Center(child: AppSplashScreen()),
        );
      }
      if (superAdminSession.mode == null) {
        _syncPreflowTheme(true);
        return const SuperAdminModeScreen();
      }
      if (superAdminSession.mode == SuperAdminEntryMode.superAdmin) {
        _syncPreflowTheme(true);
        return const SuperAdminHomeScreen();
      }
      _syncPreflowTheme(true);
    }

    return identityAsync.when(
      loading: () => const Scaffold(
        body: Center(child: AppSplashScreen()),
      ),
      error: (_, __) => const CreateAuthAccountScreen(),
      data: _buildResolvedScreen,
    );
  }

  Widget _buildResolvedScreen(UserIdentity? identity) {
    final firebaseUser = ref.watch(authStateProvider).value;
    if (firebaseUser == null) {
      _syncPreflowTheme(true);
      return const CreateAuthAccountScreen();
    }
    if (identity == null) {
      _syncPreflowTheme(true);
      return const CompleteProfileScreen();
    }

    final membershipsAsync = ref.watch(myMembershipsProvider);
    if (membershipsAsync.isLoading) {
      return const Scaffold(
        body: Center(child: AppSplashScreen()),
      );
    }
    final memberships = membershipsAsync.asData?.value ?? const [];
    final approvedMemberships =
        memberships.where((membership) => membership.approved).toList();

    if (approvedMemberships.isEmpty) {
      _syncPreflowTheme(true);
      return const GuestShellScreen();
    }

    final appConfig = ref.watch(appConfigProvider).value;
    final normalizedEmail = firebaseUser.email?.trim().toLowerCase() ?? '';
    final isChurchAdmin = appConfig != null &&
        normalizedEmail.isNotEmpty &&
        appConfig.isAdmin(normalizedEmail);

    _restoreSelectedChurchIfNeeded(identity, approvedMemberships);
    if (appConfig?.superAdminDisabled == true) {
      _syncPreflowTheme(true);
      return AdminModeScreen(
        messageOverride: ref.t('super_admin.disabled_message'),
      );
    }
    if (appConfig?.adminMode.enabled == true && !isChurchAdmin) {
      _syncPreflowTheme(true);
      return const AdminModeScreen();
    }
    _syncPreflowTheme(false);
    return const ChurchTabScreen();
  }
}
