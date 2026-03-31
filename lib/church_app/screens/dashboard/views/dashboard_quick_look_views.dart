part of 'package:flutter_application/church_app/screens/dashboard/dashboard_screen.dart';

class _DashboardPrayerQuickLook extends StatelessWidget {
  const _DashboardPrayerQuickLook({
    required this.prayers,
    required this.isLoading,
  });

  final List<PrayerRequest> prayers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final anonymousPrayers =
        prayers.where((prayer) => prayer.isAnonymous).toList(growable: false);

    if (isLoading && prayers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prayers.isEmpty) {
      return const _DashboardEmptyState(
        title: 'No active prayers right now',
        subtitle:
            'When requests are submitted, this section will surface them for quick review.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardPrayerInsightsBanner(
          totalCount: prayers.length,
          anonymousCount: anonymousPrayers.length,
        ),
        const SizedBox(height: 16),
        ...prayers.take(3).map(
              (prayer) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DashboardQuickLookTile(
                  icon: prayer.isAnonymous
                      ? Icons.visibility_off_outlined
                      : Icons.favorite_outline_rounded,
                  title: prayer.title.trim().isEmpty
                      ? 'Prayer Request'
                      : prayer.title,
                  subtitle: prayer.description.trim().isEmpty
                      ? 'No description provided.'
                      : prayer.description,
                  trailing: 'Until ${_dateLabel(prayer.expiryDate)}',
                ),
              ),
            ),
      ],
    );
  }
}

class _DashboardPrayerInsightsBanner extends StatelessWidget {
  const _DashboardPrayerInsightsBanner({
    required this.totalCount,
    required this.anonymousCount,
  });

  final int totalCount;
  final int anonymousCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_outline_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$totalCount active requests',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$anonymousCount anonymous',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onSurface.withValues(alpha: 0.84),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAnnouncementQuickLook extends StatelessWidget {
  const _DashboardAnnouncementQuickLook({
    required this.announcements,
    required this.isLoading,
  });

  final List<Announcement> announcements;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (announcements.isEmpty) {
      return const _DashboardEmptyState(
        title: 'No active announcements',
        subtitle:
            'Once live announcements are published, they will appear here.',
      );
    }

    return Column(
      children: announcements
          .take(3)
          .map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DashboardQuickLookTile(
                icon: Icons.campaign_outlined,
                title: announcement.title.trim().isEmpty
                    ? 'Announcement'
                    : announcement.title,
                subtitle: announcement.body.trim().isEmpty
                    ? 'No announcement body provided.'
                    : announcement.body,
                trailing: '',
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DashboardEventQuickLook extends StatelessWidget {
  const _DashboardEventQuickLook({
    required this.events,
    required this.isLoading,
  });

  final List<Event> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) {
      return const _DashboardEmptyState(
        title: 'No active events',
        subtitle:
            'When events are scheduled, they will show up here as a quick pulse.',
      );
    }

    return Column(
      children: events
          .take(3)
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DashboardQuickLookTile(
                icon: Icons.event_note_rounded,
                title: event.title.trim().isEmpty ? 'Event' : event.title,
                subtitle: event.location.trim().isNotEmpty
                    ? '${event.location} • ${event.timing}'
                    : event.timing,
                trailing: event.type.name,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DashboardQuickLookTile extends StatelessWidget {
  const _DashboardQuickLookTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onSurface.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
