# Notifications and Deep Links

## Purpose

Notifications keep users aware of church activity and route them to the exact
in-app destination. The system combines FCM topics, user token storage, local
foreground presentation, queued notification requests and event-triggered
Cloud Functions.

## Topic model

- Church topic: all authorized members of one church.
- Group topic: members assigned to a specific church group.
- User topic: one church-scoped user.
- Topic segments are sanitized consistently on client and backend.
- Token/topic subscriptions are refreshed after permission, token refresh,
  church switch and group membership change.
- The permission prompt uses the opaque themed modal surface, shared grab
  handle and compact top spacing so underlying Home content cannot show through.

## Current notification sources and destinations

| Kind | Audience | Tap destination |
|---|---|---|
| `feed_post_created` | Church members/admins per queue rules | Feed/church content |
| `article_created` | Church members | For You -> Articles |
| `prayer_request_created` | Church admins | For You -> Pray for Others |
| `prayer_request_visible` | Church members | For You -> Pray for Others |
| `live_church` | Church members when enabled | For You -> Live Church |
| `faith_daily_loop` / `faith_engagement` | Church members | For You -> Daily Faith |
| `circle_response_created` / `faith_circles` | Circle group except author | For You -> Circles |

Studio also supports a general church-topic notification composer.

## Web push

Web push is **on**. It was never unavailable — the FCM pipeline was already
whole (the server resolves audience from membership to uids to registered
tokens, and `topic` is legacy and ignored), and the browser half was simply
switched off.

- `web/firebase-messaging-sw.js` is the service worker the SDK registers by
  name at the site root. Without it the browser has nowhere to deliver a
  push while the tab is closed, so `getToken()` fails and the web app is
  unreachable. It only initialises messaging: every payload this app sends
  carries a `notification` block, which the SDK's own handler displays, and
  an `onBackgroundMessage` that also called `showNotification` would show
  each notification twice.
- Its Firebase config duplicates `lib/firebase_options.dart` because a
  service worker has no bundler. Those values are public identifiers that
  already ship in every web build, but they must be kept in step by hand.
- `showRemoteMessageNotification` still returns early on web, deliberately:
  the service worker draws the background case, and the SDK withholds
  foreground messages because the person is already looking at the app.
- Devices register with platform `web`; `defaultTargetPlatform` in a browser
  reports the host OS, so a Mac browser used to file itself as "macOS".
- No server change was needed, and no functions deploy.

**iPhone is the one real limit.** Safari delivers web push only to a site
added to the Home Screen; Chrome, Edge, Firefox and Android need just the
permission prompt.

`webPushVapidKey` is null on purpose: with no key the SDK falls back to
Firebase's own default application server key. Setting the project's own
Web Push certificate stops relying on that, at the cost of invalidating
tokens issued under the old one.

## Technical map

- Client: `services/notification_service.dart`, `FCM_notification_service.dart`,
  app shell and For You anchor handling.
- Backend: article/prayer/circle/live triggers and
  `processQueuedChurchNotification`.
- Requests: `churches/{churchId}/notification_requests/{id}`.
- User token: church user record `authToken`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| NOTIFY-01 | First permission allow/deny | Prompt is not duplicated; settings state matches OS result. |
| NOTIFY-02 | Church switch | Old church topics unsubscribe and new church topics subscribe. |
| NOTIFY-03 | Group membership change | Group topics update; old group messages stop. |
| NOTIFY-04 | FCM token refresh | User record and subscriptions update without duplicate listener. |
| NOTIFY-05 | Foreground message | One local notification/presentation; app remains stable. |
| NOTIFY-06 | Tap in foreground/background/terminated | Same correct tab/section opens in all three states. |
| NOTIFY-07 | Article notification | Opens article destination. |
| NOTIFY-08 | Prayer admin/member notifications | Correct audience only; opens Pray for Others. |
| NOTIFY-09 | Circle response | Target group receives it; author and unrelated groups do not. |
| NOTIFY-10 | Live notification | Sent once per broadcast only when church setting enabled. |
| NOTIFY-11 | Duplicate queue/event delivery | Idempotency prevents duplicate fan-out. |
| NOTIFY-12 | Invalid/missing `kind` | App opens safely without wrong navigation. |
| NOTIFY-13 | Open permission prompt over Home | Sheet surface is opaque with one grab handle; Home content does not show through. |
| NOTIFY-14 | Allow notifications in a desktop browser, then background the tab and have the church post | The push appears as a system notification; clicking it focuses the app. |
| NOTIFY-15 | Allow notifications, keep the tab focused, then have the church post | No duplicate system notification — the SDK withholds foreground messages by design. |
| NOTIFY-16 | Check the device registry after granting on web | The device is recorded with platform `web`, not the host operating system. |
| NOTIFY-17 | Add the site to the Home Screen on iPhone, then allow | Push arrives; without the Home Screen step Safari offers no permission at all. |
| NOTIFY-18 | Tap a feed-post notification as a member with only Home and For You | Opens Home. It must not throw a RangeError reaching for the old Community tab. |
