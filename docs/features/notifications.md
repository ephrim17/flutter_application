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

