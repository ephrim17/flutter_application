import 'package:flutter/material.dart';

/// One tappable thing in the footer — a contact or a social link.
///
/// Contacts and socials used to be laid out by two different rules: contacts
/// were `Expanded` across the whole row, so on a desktop window three of them
/// sat in the far corners of a 1,400px bar, while the socials were a centred
/// row with a fixed 20px gap. The two groups looked unrelated and the footer
/// read as broken rather than roomy.
///
/// Both now use this one tile inside a centred [Wrap]: a fixed width, so the
/// items form an even grid at any size and reflow onto a second line on a
/// phone instead of being squeezed; and one icon treatment, so a contact and
/// a social link are plainly the same kind of thing.
class FooterActionTile extends StatelessWidget {
  const FooterActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// Null disables the tile. A tile that looks pressable and does nothing is
  /// worse than one that is visibly inert, which is what the social icons
  /// were before — they carried a `url` that nothing ever opened.
  final VoidCallback? onTap;

  /// Wide enough for "Facebook" and "Location" at the label size, narrow
  /// enough that three fit across a 320dp phone.
  static const double tileWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final tint = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: tileWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: enabled ? 0.12 : 0.08),
                ),
                child: Icon(icon, size: 22, color: tint),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The centred, reflowing row the footer lays its tiles out in.
class FooterActionWrap extends StatelessWidget {
  const FooterActionWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: 4,
      runSpacing: 4,
      children: children,
    );
  }
}
