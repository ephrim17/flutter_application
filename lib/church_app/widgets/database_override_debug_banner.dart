import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/services/firestore/firestore_provider.dart';

/// Wraps [child] with a corner ribbon naming the active Firestore database
/// whenever it isn't [defaultFirestoreDatabaseId] — debug builds only.
///
/// Forgetting `--dart-define=FIRESTORE_DATABASE_ID=...` on a migration build
/// silently falls back to production (the safe default), which also means it
/// silently passes unnoticed. This banner is the visible tripwire for that —
/// see KT Files/architecture/user-church-decoupling-migration.md §3.
class DatabaseOverrideDebugBanner extends StatelessWidget {
  const DatabaseOverrideDebugBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || firestoreDatabaseId == defaultFirestoreDatabaseId) {
      return child;
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: firestoreDatabaseId,
        location: BannerLocation.topEnd,
        color: Colors.deepOrange,
        child: child,
      ),
    );
  }
}
