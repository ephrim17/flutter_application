# Studio

## Purpose and access

Studio is the church-admin workspace for church identity, content, engagement
and app configuration. Every read/write is scoped to the active church. The
drawer shows Studio only to a church admin when `studioEnabled` is true.

## Tool catalogue

### Brand and identity

- Theme colours and preview.
- About/church profile.
- Pastor CRUD, photos and primary pastor.
- Footer contact and social-item CRUD.

### Content and worship

- Announcements with optional image, priority, active state and expiry.
- Events including recurring weekly events.
- Articles with creator/updater footprint.
- Daily Verse and Promise reference pickers.
- Bible Swipe verse list/version update.

### Engagement and layout

- Daily Faith and Circles authoring.
- Live Church YouTube configuration.
- Home, For You and Faith Engagement sub-item enable/order controls.
- Topic notification composer.
- Session prompt configuration.

### Admin controls

- Church maintenance/admin mode.
- Meaningful admin-email CRUD rather than a raw comma-separated field.

Global/church Bible Learning is deliberately not managed here; only super admin
can manage it.

## Shared UX rules

- Use common text fields/dropdowns, popup menus and modal container/handle.
- Forms scroll above keyboard and safe areas; long content cannot overlap.
- Destructive actions require confirmation.
- Admin email removal cannot leave the church without a final required admin.
- Upload failures preserve entered form data and allow retry.
- Section configuration streams update member pages without pull-to-refresh.

## Technical map

- UI: `screens/side_drawer/studio_screen.dart`,
  `faith_engagement_studio_screen.dart`.
- Repository: `services/studio/studio_repository.dart`.
- Providers: app config, home/For You configs and feature-specific providers.
- Notification fan-out: `notification_requests` and
  `processQueuedChurchNotification`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| STUDIO-01 | Member/non-admin opens route directly | Access denied; no data mutation. |
| STUDIO-02 | Switch churches while Studio used | Tools rebind to new church; no old data write. |
| STUDIO-03 | Theme save/invalid colour | Valid palette updates app; invalid input is blocked. |
| STUDIO-04 | About/footer/pastor CRUD | Create/edit/delete streams update member UI; primary pastor syncs church fields. |
| STUDIO-05 | Announcement image/expiry form | No overflow; image upload and expired status work. |
| STUDIO-06 | Event recurring/non-recurring | Correct record fields and one recurrence advancement. |
| STUDIO-07 | Article creation | Creator footprint is stored and one member notification is queued. |
| STUDIO-08 | Daily/Promise Bible picker | Valid reference saves; invalid range cannot save. |
| STUDIO-09 | Bible Swipe edit | Verse list and fetch version update atomically. |
| STUDIO-10 | Reorder/disable sections/sub-items | Member Home/For You reflects exact order and visibility live. |
| STUDIO-11 | Live Church settings | Channel validation, auto-detect and notification toggles persist. |
| STUDIO-12 | Notification composer | Required fields validate; one request sends to correct church topic. |
| STUDIO-13 | Prompt/admin mode | Prompt deduplicates; maintenance blocks members but not admins. |
| STUDIO-14 | Admin email add/edit/delete/duplicate | CRUD is clear, normalized and prevents duplicate/removing final admin. |
| STUDIO-15 | Keyboard/small screen/large text | Every editor remains scrollable with visible actions and no overlap. |
| STUDIO-16 | Offline/double-submit | No duplicate record; draft/error recovery is clear. |

