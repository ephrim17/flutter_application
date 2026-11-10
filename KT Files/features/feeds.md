# Feeds

## Purpose

Feeds is embedded as the "Community" segment inside the For You tab (see
[For You content](for-you-content.md)) rather than its own bottom tab; the
screen widget and behaviour below are unchanged.

Feeds provide church-local and global social posts. Posts support text,
hashtags, multiple images, author details, optional shared profile information,
pinning, promotion to global scope, search and fast movement between latest and
older content.

The global scope is also the whole of `SelectChurchScreen`'s body (see
[Authentication and Entry](authentication-and-entry.md)) — `GlobalFeedListView`
shows the same feed inline, with no create-post action, so someone still
choosing a church sees the same cross-church activity before they've joined
anything.

**Tapping a post card navigates nowhere, by design.** Both feed lists used to
open a Reels-style vertical full-screen pager at the tapped post
(`CommunityFullScreenViewer` / `GlobalFeedFullScreenViewer`, sharing
`CommunityViewerPageView`). An ordinary tap anywhere on a card therefore
replaced the feed with a second, differently-shaped way of reading the same
posts — unannounced, and easy to trigger by accident while scrolling. Those
screens and `FeedCard`'s `fullBleed` / `onTap` / `onDescriptionTap`
parameters were all removed; the card is the whole post. Everything the
viewer offered is on the card: the description expands in place, an image
opens the shared gallery viewer, and the reaction pill opens the reactor
list. Reinstating a tap target here means adding a single-post detail screen,
not bringing the pager back.

## Roles and actions

- Approved members can read and create church posts.
- Authors can edit their post only during the first 30 minutes.
- Permitted users can delete according to the app/rules policy.
- Church admins receive common-menu actions for pin, global/un-global and
  delete. Only one post per scope is pinned at a time.
- Global promotion uses the privileged `setFeedPostGlobal` callable and retains
  source IDs. Removing global status deletes the copy and updates the source.

## Media and presentation

- Creation accepts multiple images and stores ordered `imageUrls`, retaining
  legacy `imageUrl` compatibility.
- Cards render a gallery; tapping opens the shared WhatsApp-style viewer with
  paging and zoom.
- Feed images also support a two-finger pinch directly on the card, without
  opening the full-screen viewer: `panEnabled: false` on the inline
  `InteractiveViewer` means only a genuine two-finger pinch engages it, so a
  single-finger drag still scrolls the feed / pages the image carousel as
  normal. Releasing the pinch animates the image back to its original size.
- User avatar/name opens the shared user quick card.
- Hashtags are normalized, deduplicated and searchable.
- The screen uses live/optimistic updates so moderation changes appear without
  pull-to-refresh.
- Create/edit sheets use the shared grab handle as their dismiss affordance and
  do not repeat it with a Cancel button.
- Post images fade in over ~260ms (`appImageFadeDuration`) against a still
  neutral placeholder. They used to sweep a shimmer highlight left-to-right
  while loading; in a feed that is mostly images, several sweeps at once read
  as motion the eye chases, drawing attention to the loading rather than the
  post. The same fade now covers the full-bleed feed image, link-preview
  thumbnails (`ShimmerImage`, which despite its name no longer shimmers) and
  the per-post church logo.
- Reactions (WhatsApp-channel style) — a round button sits in the bottom-right
  corner of every card. Its own state, always live: a neutral "react" icon
  when the signed-in user hasn't reacted, or their own chosen emoji once
  they have. Tapping it toggles: with no reaction, opens a fixed 5-emoji
  picker (🙏 ❤️ 🤍 👍 🎉) anchored at the button; already reacted, taps it
  away directly (no picker) rather than reopening the choice.
  **Every emoji is drawn with `emojiTextStyle`, never the app's text
  style.** The theme is `GoogleFonts.interTextTheme`, and Inter ships its own
  monochrome glyph for U+2764 — so "❤️" (U+2764 plus the emoji variation
  selector) rendered as a thin grey heart until the picker was pointed at the
  platform emoji fonts instead. The same applies to the reactions sheet's
  filter chips, which is why they draw the emoji and its count as two
  separate `Text`s rather than one "❤️ 3" string. Note 🤍 is a pale emoji by
  nature and still reads faintly on a white sheet; that is the emoji, not the
  font. Both directions
  update the button instantly via a dedicated per-user listener — no refresh
  needed, unlike most other feed mutations in this doc. The button's aggregate
  data (`reactionSummary`/`reactionTotal` on the post) is written only by a
  Cloud Function — reacting itself never needs write access to the post doc,
  only to the reactor's own reaction doc.
- The **reaction pill** sits in the opposite (bottom-left) corner of the card:
  up to three emoji, most-reacted first, then the total. Tapping it opens the
  "N Reactions" sheet — a filter chip per emoji plus "All", and a list of
  reactors showing avatar and name only, never a phone number. It renders
  nothing at all on a post with no reactions, so a quiet feed stays quiet.
  Long-pressing the corner reaction button opens the same sheet.
  - **Open to anyone who can see the post.** It was previously restricted to
    the post's author and admins, with no pill and nothing but an
    undiscoverable long-press to reach it — which meant, for example, that
    `ephrim17@gmail.com` (not in `tnbm`'s `config/app.admins`) had no way to
    see reactions on any `tnbm` post they hadn't written, and no indication
    why. `firestore.rules` already grants read on the whole `reactions`
    subcollection to any approved member (any verified-email user, on the
    global feed), so the restriction bought no privacy — it only produced a
    dead gesture.
  - The pill reconciles a **snapshot aggregate with a live reaction**, which
    is the subtle part. `reactionSummary` is denormalized by a Cloud Function,
    and the feed paginates with one-shot `get()`s, so the aggregate a loaded
    card holds never moves on its own; the reactor's own reaction, by
    contrast, is a live single-doc listener. `feedReactionPillSummary`
    (`helpers/feed_reaction_summary.dart`) applies only the difference
    between the reaction as the aggregate saw it — the first value that live
    listener produced — and what it is now. So the count moves the instant
    you react and still agrees with the server after a refetch. `FeedCard`
    resets that baseline in `didUpdateWidget` whenever the post's aggregate
    changes, or a refetch that already counts your reaction would double it.
    Other people's reactions arriving after fetch time aren't reflected until
    the next refresh — the same staleness the rest of the card carries.
    Counts are clamped at zero, so a mid-flight aggregate can't render a
    negative.

## Technical map

- Screen: `screens/feed_screen.dart`.
- Card/modal: `widgets/feed_card_widget.dart`, `feed_post_modal.dart`.
- Gallery: `widgets/app_image_gallery_viewer.dart`.
- Repository/model: `services/feed_repository.dart`, `models/feed_model.dart`.
- Data: `churches/{churchId}/feeds/{postId}`, `globalFeeds/{globalPostId}`.
- Storage: `churches/{scope}/feeds/{postId}/images/...`.
- Backend: `setFeedPostGlobal`, notification request processing.
- Reactions: the corner button is `_FeedReactionButton` inside
  `widgets/feed_card_widget.dart` (emoji via `helpers/emoji_text_style.dart`);
  the count pill is `widgets/feed_reaction_summary_pill.dart`, whose display
  maths lives in `helpers/feed_reaction_summary.dart`;
  `widgets/modals/feed_reactions_sheet.dart`
  is the "N Reactions" sheet. Also `services/feed_reaction_repository.dart`,
  `providers/feed_reaction_provider.dart`, `models/feed_reaction_model.dart`.
  Data: `.../feeds/{postId}/reactions/{uid}` (church) or
  `globalFeeds/{postId}/reactions/{uid}` (global), one self-only doc per
  person. Backend: `onChurchFeedReactionWrite`/`onGlobalFeedReactionWrite`
  (Cloud Functions, `functions/src/feedReactions.ts`) recompute
  `reactionSummary`/`reactionTotal` on the parent post from that
  subcollection on every reaction write.
  - **That write uses `mergeFields`, never `merge: true`.** A plain merge
    deep-merges map fields, so writing a fresh `{👍: 1}` over a stored
    `{👍: 1, ❤️: 1}` left the ❤️ key behind — `reactionSummary`
    could only ever grow, and an emoji nobody still reacted with stayed on
    the pill forever. `reactionTotal` is a scalar and always overwrote
    correctly, so the signature of the bug is a summary whose counts don't
    add up to the total. Found on 2026-11-10, when the new pill showed "2"
    on a `tnbm` post whose sheet listed one reactor; 1 of 76 posts had
    drifted. The aggregate is always a **full recount**, never an
    increment, so a missed or out-of-order trigger can't drift it on its
    own — only that merge could.
  - `functions/scripts/repair/reactionAggregates.ts`
    (`npm --prefix functions run repair:reactions`) audits every post's
    aggregate against its reaction docs and, with `--write`, repairs the
    drifted ones. It audits only by default, and only writes posts that
    actually disagree.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FEED-01 | Create text-only post | It appears once at the top and persists after relaunch. |
| FEED-02 | Create post with 1/multiple images | Correct order displays; viewer pages and zooms without overflow. |
| FEED-03 | Reject/cancel image selection or upload failure | Draft remains usable and no orphan post/file remains. |
| FEED-04 | Edit at 29:59 and after 30:00 | First is allowed; second has no edit action/server write. |
| FEED-05 | Pin a second post | New post is pinned and previous post is automatically unpinned. |
| FEED-06 | Make global/unmake global | UI updates immediately; source/copy metadata converges correctly. |
| FEED-07 | Unauthorized global/pin request | Backend rejects even if invoked outside UI. |
| FEED-08 | Delete local promoted post/global linked copy | Both linked documents update/delete correctly; owned images are removed. |
| FEED-09 | Search and hashtag navigation | Matching content loads; clear returns full list. |
| FEED-10 | Jump latest/jump older | Button moves quickly in both directions and respects list bounds. |
| FEED-11 | Tap author/profile contact | One phone icon appears; confirmation precedes dialer/mail/maps. |
| FEED-12 | Rapid action/double-tap/offline | No duplicates, stale menu or crash; error can be retried. |
| FEED-13 | Church switch | No local posts from previous church; global posts remain global. |
| FEED-14 | Open create/edit sheet | The create control has an accessible label; the sheet has one shared small grab handle and no redundant Cancel button. |
| FEED-15 | Two-finger pinch on a feed card image; separately, single-finger vertical drag / horizontal swipe on a multi-image card | Pinch zooms the image in place and snaps back on release without opening the full-screen viewer; single-finger drags still scroll the feed and page between images exactly as before. |
| FEED-16 | Tap the corner reaction button with no reaction yet | A 5-emoji picker opens anchored at the button; picking one immediately turns the button into that emoji, no refresh needed. |
| FEED-17 | Tap the corner button again once it shows your emoji | Your reaction is removed directly (no picker reopens); the button reverts to the neutral icon immediately. |
| FEED-18 | Tap the button, pick a different emoji than your current one | Your reaction switches to the new emoji; still counts as one reaction (no duplicate). |
| FEED-19 | Long-press the corner reaction button | "N Reactions" sheet opens with a chip per emoji (plus "All") and a list of reactors — avatar and name only, no phone number. |
| FEED-20 | Tap the reaction pill as a regular member who is neither the author nor any kind of admin | The same "N Reactions" sheet opens and lists every reactor. (Was a silent no-op before the pill existed.) |
| FEED-21 | Scroll a feed of posts with and without reactions | Posts with reactions show a bottom-left pill (up to 3 emoji, most-reacted first, then the total); posts with none show no pill at all, not a "0". |
| FEED-22 | React to a post that already has reactions, without refreshing | The pill's total increments by exactly one and your emoji appears in it immediately — the denormalized aggregate on the post has not been refetched. |
| FEED-23 | React, then change your emoji, then remove it — all without refreshing | The total goes +1, holds steady while the emoji moves across, then returns to its original value. It never shows a negative or a double count. |
| FEED-24 | React to a post, then pull to refresh the feed | The pill shows the same total after the refetch as it did before — the server aggregate and the local adjustment agree, no double count. |
| FEED-25 | Tap a post card anywhere that isn't an image, the author row, a hashtag, the pill or the reaction button | Nothing happens — no navigation. Confirms the Reels-style full-screen pager is gone from both the Community list and `SelectChurchScreen`'s global feed. |
| FEED-26 | Open a post with exactly one reaction and read the sheet's heading | It reads "1 Reaction", not "1 Reactions" (`ui.feed_reactions.title_one`). |
| FEED-27 | React with one emoji, remove it, react with a different one, then pull to refresh | The pill shows only the emoji currently reacted with — the removed one's key does not linger. Guards the `mergeFields` fix in `recomputeReactionAggregate`. |
| FEED-28 | Run `npm --prefix functions run repair:reactions` against production | Reports 0 drifted posts. Any drift means a reaction write path is bypassing `recomputeReactionAggregate` or the merge regression is back. |
