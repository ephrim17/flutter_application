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
shows the same feed inline, and tapping a post opens
`GlobalFeedFullScreenViewer`, which reuses `CommunityViewerPageView`
(extracted from `CommunityFullScreenViewer`), global-only and with no
create-post action — someone still choosing a church sees the same
cross-church activity before they've joined anything.

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
- Reactions (WhatsApp-channel style) — a round button sits in the bottom-right
  corner of every card. Its own state, always live: a neutral "react" icon
  when the signed-in user hasn't reacted, or their own chosen emoji once
  they have. Tapping it toggles: with no reaction, opens a fixed 5-emoji
  picker (🙏 ❤️ 🤍 👍 🎉) anchored at the button; already reacted, taps it
  away directly (no picker) rather than reopening the choice. Both directions
  update the button instantly via a dedicated per-user listener — no refresh
  needed, unlike most other feed mutations in this doc. There is no
  public-facing count or "who reacted" pill on the card itself — the "N
  Reactions" breakdown (a filter chip per emoji, a list of reactors — avatar
  and name only, no phone) is reached only by long-pressing the button, and
  only opens at all for the post's own author or an admin (church admin for
  a church post, or for the church a global post came from); everyone else's
  long-press is a silent no-op. The button's aggregate data
  (`reactionSummary`/`reactionTotal` on the post) is written only by a Cloud
  Function — reacting itself never needs write access to the post doc, only
  to the reactor's own reaction doc.

## Technical map

- Screen: `screens/feed_screen.dart`.
- Card/modal: `widgets/feed_card_widget.dart`, `feed_post_modal.dart`.
- Gallery: `widgets/app_image_gallery_viewer.dart`.
- Repository/model: `services/feed_repository.dart`, `models/feed_model.dart`.
- Data: `churches/{churchId}/feeds/{postId}`, `globalFeeds/{globalPostId}`.
- Storage: `churches/{scope}/feeds/{postId}/images/...`.
- Backend: `setFeedPostGlobal`, notification request processing.
- Reactions: the corner button is `_FeedReactionButton` inside
  `widgets/feed_card_widget.dart`; `widgets/modals/feed_reactions_sheet.dart`
  is the "N Reactions" sheet. Also `services/feed_reaction_repository.dart`,
  `providers/feed_reaction_provider.dart`, `models/feed_reaction_model.dart`.
  Data: `.../feeds/{postId}/reactions/{uid}` (church) or
  `globalFeeds/{postId}/reactions/{uid}` (global), one self-only doc per
  person. Backend: `onChurchFeedReactionWrite`/`onGlobalFeedReactionWrite`
  (Cloud Functions, `functions/src/feedReactions.ts`) recompute
  `reactionSummary`/`reactionTotal` on the parent post from that
  subcollection on every reaction write.

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
| FEED-19 | Long-press the corner button as the post's author or a church admin | "N Reactions" sheet opens with a chip per emoji (plus "All") and a list of reactors — avatar and name only, no phone number. |
| FEED-20 | Long-press the corner button as a regular member who isn't the author | Nothing opens — a silent no-op. |
