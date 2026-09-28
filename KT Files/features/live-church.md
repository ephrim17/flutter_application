# Live Church

## Purpose

Live Church shows an embedded player in For You while the church's stream is
running. **An admin says when to go live; the card comes down by itself.**

## Going live is manual (2026-09-28)

Automatic detection was removed because it did not work. YouTube's
PubSubHubbub feed notifies on a video being *published*, not on a stream
starting, so for a broadcast scheduled ahead of time no push ever arrived.
The only code that actively searched for a live stream ran as a side effect of
writing `live_church/config`, which is why the card appeared **only when an
admin re-saved the settings**. Production evidence, 2026-09-28: the webhook
had been invoked only at ~03:00 UTC daily (the hub's verification handshake
from the renewal job, never a content push), and `tnbm/live_church/status` had
not been touched since 13 September.

What replaced it:

- **Admin presses Go live** in Studio → the `setLiveChurchBroadcast` callable
  searches the configured channel for what is live now (or uses a pasted link,
  for a stream that is unlisted or too new to be indexed) and writes
  `live_church/status`.
- **The card still only appears when the stream is genuinely running.**
  Pressing Go live on a stream that has not started writes `monitoring: true`
  with `isLive: false`; the every-minute `refreshKnownYouTubeBroadcasts`
  flips `isLive` on when it starts. Pressing early is safe and expected.
- **Ending stays automatic.** That same job ends the card when the broadcast
  stops, at one YouTube quota unit per check.
- **Admin can end it early** with "End live card", and switching *Live
  services* off takes any card down immediately.
- Discovery automation is gone. `renewYouTubeChannelSubscriptions` was
  deleted from source **and from the project** (2026-09-28), and the `tnbm`
  channel was unsubscribed from the hub — the hub's verification GET reached
  the webhook and was answered, so no further pushes are sent for it. Any
  subscription still out there simply lapses: nothing renews them, and
  `youtubeLiveWebhook` now acknowledges and ignores pushes so a stale one
  cannot resurrect a card. `syncYouTubeChannelSubscription` only ever takes a
  card *down*. Restoring automatic detection would mean redeploying the
  renewal function and re-subscribing, not just a code revert.

## Configuration and playback

- Church admin configures channel ID, whether live services are enabled, and
  member notification in Studio — then presses Go live per service.
- `refreshKnownYouTubeBroadcasts` polls monitored broadcasts every minute for
  the "now live" and "now ended" transitions.
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
- Backend: `youtube_live.ts` exports `setLiveChurchBroadcast` (the manual
  start/stop callable, church-admin only, email compared case-insensitively),
  `refreshKnownYouTubeBroadcasts` (ready/ended transitions),
  `notifyChurchWhenYouTubeLive`, plus the now-inert
  `syncYouTubeChannelSubscription` and `youtubeLiveWebhook`.

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
| LIVE-08 | Change channel while a card is showing | The old stream's card disappears; the new channel shows nothing until an admin presses Go live. |
| LIVE-10 | Admin presses Go live while the stream is already running | Card appears for members within one refresh cycle; Studio shows "Live now". |
| LIVE-11 | Admin presses Go live before starting the stream on YouTube | "No live stream found on your channel yet" — nothing is written. With the stream created but not started, Studio shows "Waiting for the stream to start" and the card appears by itself once it begins. |
| LIVE-12 | Stream ends on YouTube | The card disappears for members within a minute, without the admin doing anything. |
| LIVE-13 | Admin presses End live card mid-stream | Card disappears immediately; the stream keeps running on YouTube. |
| LIVE-14 | Non-admin calls `setLiveChurchBroadcast` directly | Rejected `permission-denied: admin-required`; no status write. |
| LIVE-15 | Admin pastes an unlisted stream's link and presses Go live | That video is used even though the channel search would not find it. |
| LIVE-09 | Invalid channel/network failure | Studio shows recoverable error; existing app remains usable. |

