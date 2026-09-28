import 'dart:math' as math;

/// Progress, 0.0–1.0, for a Studio Daily Verse image generation.
///
/// Gemini reports nothing while it works and the callable returns only when a
/// whole language is done, so the only facts available are *how many
/// languages have finished* and *how long the current one has been running*.
/// This turns those two into a bar that moves without ever lying:
///
/// - each language owns an equal segment (two languages → 50% each), and a
///   finished language's segment is filled outright;
/// - inside the running segment the value creeps along elapsed time but stops
///   at [_segmentCeiling], so a slow run stalls just short of the next
///   milestone instead of sitting at 100% waiting, and the jump to a full
///   segment only ever happens because that language really did finish.
///
/// [expectedPerLanguage] is a typical batch duration, not a deadline —
/// overshooting it simply holds the bar at the ceiling.
double verseImageGenerationProgress({
  required int languagesDone,
  required int totalLanguages,
  required Duration elapsedInSegment,
  required Duration expectedPerLanguage,
}) {
  if (totalLanguages <= 0) return 0;
  final done = languagesDone.clamp(0, totalLanguages);
  final segment = 1 / totalLanguages;
  final completed = done * segment;
  if (done >= totalLanguages) return 1;

  final expected = expectedPerLanguage.inMilliseconds;
  if (expected <= 0) return completed.clamp(0.0, 1.0);
  final fraction =
      math.min(elapsedInSegment.inMilliseconds / expected, 1.0).clamp(0.0, 1.0);
  return (completed + segment * fraction * _segmentCeiling).clamp(0.0, 1.0);
}

/// How far into its own segment a still-running language may creep.
const double _segmentCeiling = 0.92;

/// The whole-number percentage shown to the admin.
int verseImageGenerationPercent(double progress) =>
    (progress.clamp(0.0, 1.0) * 100).round();
