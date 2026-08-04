# Live Church

## Purpose

Live Church automatically detects a configured YouTube channel's active stream,
notifies members when configured, and shows an embedded player in For You only
while a playable stream exists.

## Configuration and playback

- Church admin configures channel ID, automatic detection and member
  notification in Studio.
- Cloud Functions synchronize YouTube subscription/webhook state and periodically
  refresh known broadcasts.
- Status is stored at `churches/{churchId}/live_church/status`; configuration at
  `.../live_church/config`.
- The card plays inline first. A separate full-screen button opens landscape,
  immersive playback without app bars. Exiting restores portrait orientation.
- If embedding is not supported, the card offers a confirmed external YouTube
  action.

## Technical map

- UI/player: `sections/live_church_section.dart`,
  `widgets/adaptive_youtube_player.dart`.
- Provider/model: `live_church_provider.dart`, `live_church_model.dart`.
- Studio editor: `_LiveChurchEditor` in `studio_screen.dart`.
- Backend: `youtube_live.ts` exports webhook, synchronization, renewal, refresh
  and notification functions.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| LIVE-01 | Channel is offline | Live section is absent. |
| LIVE-02 | Valid active stream | Card appears and inline playback starts on user action. |
| LIVE-03 | Full-screen button | Player enters immersive landscape; Back returns to inline portrait. |
| LIVE-04 | Web/Android/iOS playback | Stream loads smoothly with no unsupported WebView crash. |
| LIVE-05 | Unembeddable video | Fallback appears and asks before opening YouTube. |
| LIVE-06 | Notify enabled/disabled | One church-topic notification is sent only when enabled. |
| LIVE-07 | Duplicate webhook/scheduled refresh | No duplicate member notification for same broadcast. |
| LIVE-08 | Change channel | Subscription/status follows new channel and old stream disappears. |
| LIVE-09 | Invalid channel/network failure | Studio shows recoverable error; existing app remains usable. |

