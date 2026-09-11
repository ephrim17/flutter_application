/// Shared rules for deriving a self-signup member's category and family id
/// from their own identity fields — used by both the legacy member-mode
/// form (`login_request_screen.dart`) and the lightweight self-service
/// `request_church_access_screen.dart`, so the two paths can never drift.
/// See KT Files/architecture/user-church-decoupling-migration.md §5.5.
library;

/// A single person is "family" if married, "individual" otherwise — there is
/// no explicit category picker in self-signup today.
String deriveSelfSignupCategory(String maritalStatus) {
  return maritalStatus.trim().toLowerCase() == 'married'
      ? 'family'
      : 'individual';
}

/// Slugifies [value] into a stable seed, stripping any category prefix or
/// church-id suffix it might already carry (so re-normalizing an existing
/// family id is a no-op).
String normalizeMembershipSeed(String value, String churchId) {
  final churchSuffix = churchId.toLowerCase();
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

/// Self-signup never asks for a family id directly — it derives a stable one
/// from the person's own name, scoped to category and church so two
/// unrelated "John"s in different churches (or one individual vs. family)
/// never collide.
String resolveSelfSignupFamilyId({
  required String category,
  required String name,
  required String churchId,
}) {
  final seed = name.trim();
  if (seed.isEmpty || category.isEmpty) return '';
  final normalizedSeed = normalizeMembershipSeed(seed, churchId);
  if (normalizedSeed.isEmpty) return '';
  return '${category.toLowerCase()}_${normalizedSeed}_$churchId';
}
