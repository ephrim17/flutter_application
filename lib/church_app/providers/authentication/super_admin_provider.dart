import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/user_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SuperAdminEntryMode {
  normal,
  superAdmin,
}

class SuperAdminEntrySessionState {
  const SuperAdminEntrySessionState({
    required this.isLoading,
    required this.uid,
    required this.mode,
  });

  final bool isLoading;
  final String? uid;
  final SuperAdminEntryMode? mode;

  SuperAdminEntrySessionState copyWith({
    bool? isLoading,
    String? uid,
    SuperAdminEntryMode? mode,
    bool clearMode = false,
  }) {
    return SuperAdminEntrySessionState(
      isLoading: isLoading ?? this.isLoading,
      uid: uid ?? this.uid,
      mode: clearMode ? null : (mode ?? this.mode),
    );
  }
}

class SuperAdminEntrySessionController
    extends StateNotifier<SuperAdminEntrySessionState> {
  SuperAdminEntrySessionController(this._ref)
      : super(
          const SuperAdminEntrySessionState(
            isLoading: true,
            uid: null,
            mode: null,
          ),
        ) {
    _loadForCurrentUser();
  }

  static const _uidKey = 'super_admin_entry_uid';
  static const _modeKey = 'super_admin_entry_mode';

  final Ref _ref;

  Future<void> _loadForCurrentUser() async {
    await syncForUser(_ref.read(firebaseAuthProvider).currentUser?.uid);
  }

  Future<void> syncForUser(String? uid) async {
    if (uid == null || uid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_uidKey);
      await prefs.remove(_modeKey);
      state = const SuperAdminEntrySessionState(
        isLoading: false,
        uid: null,
        mode: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, uid: uid, clearMode: true);
    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString(_uidKey);
    final storedMode = prefs.getString(_modeKey);

    if (storedUid != uid || storedMode == null) {
      state = SuperAdminEntrySessionState(
        isLoading: false,
        uid: uid,
        mode: null,
      );
      return;
    }

    state = SuperAdminEntrySessionState(
      isLoading: false,
      uid: uid,
      mode: SuperAdminEntryMode.values.firstWhere(
        (value) => value.name == storedMode,
        orElse: () => SuperAdminEntryMode.normal,
      ),
    );
  }

  Future<void> setMode(SuperAdminEntryMode mode) async {
    final uid = _ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      state = const SuperAdminEntrySessionState(
        isLoading: false,
        uid: null,
        mode: null,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uidKey, uid);
    await prefs.setString(_modeKey, mode.name);
    state = SuperAdminEntrySessionState(
      isLoading: false,
      uid: uid,
      mode: mode,
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove(_modeKey);
    state = const SuperAdminEntrySessionState(
      isLoading: false,
      uid: null,
      mode: null,
    );
  }
}

final isSuperAdminProvider = StreamProvider<bool>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(false);
      }

      return firestore
          .collection('superAdmins')
          .doc(firebaseUser.uid)
          .snapshots()
          .map((doc) => doc.exists);
    },
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});

final superAdminEntryModeProvider = StateNotifierProvider<
    SuperAdminEntrySessionController, SuperAdminEntrySessionState>((ref) {
  final controller = SuperAdminEntrySessionController(ref);
  ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
    next.whenData((user) {
      controller.syncForUser(user?.uid);
    });
  });
  return controller;
});
