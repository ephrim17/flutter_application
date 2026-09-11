import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/widgets/church_logo_avatar_widget.dart';

/// The church card used across "Your churches"/"Other churches"
/// (`SelectChurchScreen`) — originally the Discover tab's card design,
/// reused here after the Discover tab was removed.
class ChurchDiscoveryCard extends StatelessWidget {
  const ChurchDiscoveryCard({
    super.key,
    required this.church,
    this.isCurrentChurch = false,
    required this.onTap,
  });

  final Church church;
  final bool isCurrentChurch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(cornerRadius),
      onTap: onTap,
      child: Ink(
        decoration: carouselBoxDecoration(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChurchLogoAvatar(logo: church.logo, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          church.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isCurrentChurch) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              context.t('ui.go_further.current_church'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _PastorPhotoAvatar(
                    photoUrl: church.pastorPhoto,
                    size: 42,
                    onTap: () => _showPastorPhotoPreview(context, church),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChurchDiscoveryPreviewLine(
                      icon: Icons.person_outline_rounded,
                      text: _valueOrFallback(church.pastorName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ChurchDiscoveryPreviewLine(
                icon: Icons.location_on_outlined,
                text: _valueOrFallback(church.address),
              ),
              if (church.hasAnySocialLinks) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (church.facebookLink.trim().isNotEmpty)
                      _SocialBadge(
                        icon: Icons.facebook,
                        label: context.t('ui.go_further.facebook_82da'),
                      ),
                    if (church.instagramLink.trim().isNotEmpty)
                      _SocialBadge(
                        icon: Icons.camera_alt_outlined,
                        label: context.t('ui.go_further.instagram_5721'),
                      ),
                    if (church.youtubeLink.trim().isNotEmpty)
                      _SocialBadge(
                        icon: Icons.play_circle_outline_rounded,
                        label: context.t('ui.go_further.youtube_5588'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPastorPhotoPreview(
    BuildContext context, Church church) async {
  final photoUrl = church.pastorPhoto.trim();
  if (photoUrl.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_rounded,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                church.pastorName.trim().isEmpty ? 'Pastor' : church.pastorName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.t('ui.go_further.close_aec0')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PastorPhotoAvatar extends StatelessWidget {
  const _PastorPhotoAvatar({
    required this.photoUrl,
    this.size = 42,
    this.onTap,
  });

  final String photoUrl;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = photoUrl.trim();
    final theme = Theme.of(context);

    return InkWell(
      onTap: trimmed.isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: trimmed.isEmpty
            ? Icon(
                Icons.person_rounded,
                color: theme.colorScheme.primary,
                size: size * 0.5,
              )
            : Image.network(
                trimmed,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_rounded,
                  color: theme.colorScheme.primary,
                  size: size * 0.5,
                ),
              ),
      ),
    );
  }
}

class _ChurchDiscoveryPreviewLine extends StatelessWidget {
  const _ChurchDiscoveryPreviewLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SocialBadge extends StatelessWidget {
  const _SocialBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _valueOrFallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not available yet' : trimmed;
}
