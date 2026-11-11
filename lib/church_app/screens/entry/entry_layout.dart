import 'package:flutter/material.dart';

/// How wide an entry screen's content is allowed to get.
///
/// The app is laid out for a phone, where a form fills the width because the
/// width is 400dp. In a desktop browser the same form stretches to whatever
/// the window is — at 1440px the "Full name" field was over 1,400px of empty
/// box with a label at the far left, which reads as broken rather than
/// spacious.
///
/// Three entry screens already capped themselves at this number inline
/// (`email_otp_verification`, `password_reset_code`, `reset_password`). This
/// is that same number in one place, so the rest of the flow can agree with
/// them instead of each screen deciding for itself. Home has its own, wider
/// cap (`homeSectionMaxWidth`) because it shows cards rather than a form.
const double entryMaxWidth = 460.0;

/// Centres [child] and stops it growing past [entryMaxWidth].
///
/// Below that width this changes nothing at all, so a phone is unaffected.
class EntryWidthLimit extends StatelessWidget {
  const EntryWidthLimit({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: entryMaxWidth),
        child: child,
      ),
    );
  }
}
