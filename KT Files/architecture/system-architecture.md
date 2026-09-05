# System Architecture

## Purpose

Church Tree is a multi-tenant Flutter application. A user may belong to one or
more churches, but the authenticated app operates within one selected church at
a time. Church data must remain scoped to that church. Global feeds, global
prayer requests, global Bible modules, and super-admin records are explicit
exceptions.

## Runtime layers

| Layer | Responsibility | Main location |
|---|---|---|
| Presentation | Screens, navigation, modals, cards and forms | `lib/church_app/screens/`, `lib/church_app/widgets/` |
| State | Riverpod providers, controllers and dependency wiring | `lib/church_app/providers/` |
| Domain | Serializable models and business-state helpers | `lib/church_app/models/` |
| Data | Firestore, Auth, Storage, messaging and mutations | `lib/church_app/services/` |
| Shared helpers | Validation, formatting, localization and external launch confirmation | `lib/church_app/helpers/` |
| Backend | Privileged writes, email, schedules and FCM fan-out | `functions/src/` |

UI code should consume providers and repositories rather than rebuilding
Firestore queries. New Firestore paths should be added to
`services/firestore/firestore_paths.dart` where possible.

## Identity and authorization

- Firebase Authentication provides the global identity (`uid`, email).
- A church membership is stored at `churches/{churchId}/users/{uid}`.
- `approved` controls member access to a church.
- Church admin status is derived from the normalized signed-in email appearing
  in `churches/{churchId}/config/app.admins`.
- Super-admin status is global and requires an enabled matching record in
  `superAdmins`.
- Church admin and super admin are separate authorities; never infer one from
  the other.

Privileged operations must be enforced by backend rules or Cloud Functions,
not only by hiding UI controls.

## Entry state machine

```text
App start
  -> onboarding incomplete: onboarding
  -> signed out: authentication
  -> super admin: choose normal or super-admin mode
  -> no selected membership: church selection/request access
  -> membership pending: pending approval
  -> church disabled or maintenance mode: blocked notice
  -> approved: church tab shell
```

`AppEntry` is the main decision point. Selected-church restoration is local,
while membership and configuration are validated from Firebase.

## Core Firestore ownership

```text
churches/{churchId}
  config/app
  users/{uid}
  feeds/{postId}
  prayer_requests/{prayerId}
  announcements/{announcementId}
  events/{eventId}
  articles/{articleId}
  pastor/{pastorId}
  groups/{groupId}/users/{uid}
  equipments/{equipmentId}
  home_sections/{sectionId}
  for_you_section/{sectionId}
  live_church/{config|status}
  youth_circles/{circleId}/responses/{responseId}
  faith_reflections/{reflectionId}
  faith_engagement/{user-day-id}
  learning_config/main
  learning_modules/{moduleId}
  learning_results/{resultId}
  users/{uid}/learning_progress/progress
  notification_requests/{requestId}

globalFeeds/{globalPostId}
globalPrayerRequests/{globalPrayerId}
learning_modules/{globalModuleId}
users/{uid}
superAdmins/{recordId}
globalFeedback/{feedbackId}
passwordResetChallenges/{opaqueHmacId}  # server-only transient data
```

Global copies of church posts and prayers retain source church/document IDs so
promotion and removal can update both sides consistently.

## Storage ownership

Common prefixes include:

- `churches/{churchId}/feeds/{postId}/images/...`
- `churches/{churchId}/announcements/...`
- `churches/{churchId}/pastorPhotos/...`
- profile-photo paths owned by the user/church profile service
- `learning_modules/{moduleId}/{sectionId}/...`
- `churches/{churchId}/learning_modules/{moduleId}/{sectionId}/...`

Deleting content that owns files should remove both the database record and
owned Storage objects. Church-customized learning resources must remain
independent from later global module changes.

## Configuration and text

`churches/{churchId}/config/app` controls feature flags, admins, appearance,
maintenance mode, prompts, daily/promise references, and text overrides.
Section documents control enabled state and ordering for Home and For You.

All user-visible text must use `preAuthDefaultTextContents` before church
configuration is available or `defaultChurchTextContents` after entry, rendered
through `context.t(...)`/`ref.t(...)`. Dynamic sentences use named parameters.

## Notification architecture

Clients subscribe to church, group and user topics after permission and token
registration. App writes notification requests or domain records; Cloud
Functions send FCM messages and attach a `kind`. The app maps `kind` to a tab or
For You anchor. Notification handlers must support foreground, background and
terminated launches.

## Reliability invariants

- Every church read/write carries the currently resolved `churchId`.
- Async UI work checks `mounted` before using `context` or Riverpod `ref`.
- Streams own live refresh; optimistic state may improve speed but must converge
  with Firestore.
- Empty, loading, error and permission-denied states are first-class UI states.
- External phone, mail and map actions require confirmation.
- The app remains portrait except explicit full-screen video playback.
- Dormant finance code is not exported, routed or displayed.

