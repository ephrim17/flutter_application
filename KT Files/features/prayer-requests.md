# Prayer Requests and Pray for Others

## Purpose

Members can submit personal prayer requests and optionally share them with their
church. Admins can manage all church requests. For You shows active
church-visible requests as Pray for Others.

**Prayer requests never leave their church (since 2026-11-10).** An earlier
build let a church admin promote a request into a cross-church
`globalPrayerRequests` collection, shown as a third "Global" scope box. That
is gone: the scopes are My Requests and, for admins, All Requests, both
scoped to the selected church. `PrayerSegment.global`,
`globalPrayerRequestsProvider`, `watchGlobalPrayers()`, `setPrayerGlobal()`,
`FirestorePaths.globalPrayerCollection` and the `isGlobal` / `sourceChurchId`
/ `sourcePrayerId` / `sourceChurchName` fields on `PrayerRequest` were all
removed, and `addPrayer` no longer writes `isGlobal`. A prayer request is the
most personal thing the app stores, so the scope that governs it is now a
single unambiguous one — the church you are in — rather than a per-request
flag an admin could flip.

## Views and rules

- Modern scope boxes show title and count for My Requests and, for admins,
  All Requests. There is no third scope.
- Request fields: title, description, anonymous flag, visible-to-church flag and
  required expiry date.
- Expiry must be today through 30 days from today. Validation appears inside
  the prayer modal, above any underlying screen.
- Members see/edit their own requests according to authorization. Admins can
  view every active request in the church.
- The per-card overflow menu is Edit (own requests) and Delete only.
- Save with visible-to-church enabled notifies church members. New requests also
  notify church admins. Notification taps open For You at Pray for Others.
- Empty scopes use a common inline empty-state container and New Request action;
  there is no duplicate floating action button.

## Technical map

- UI: `screens/side_drawer/prayer_request_screen.dart`,
  `screens/for_you/sections/pray_for_others_section.dart`.
- **One card, both places**: `widgets/prayer_request_card.dart`
  (`PrayerRequestCard`, plus `PrayerRequestIcon`). For You used to draw its
  own narrower, fixed-height carousel tile, so the same request rendered at
  two different sizes depending on where you met it. Both screens now build
  the same widget, so padding, radius, type scale and line clamps cannot
  drift apart again. The Prayer Requests screen passes its overflow menu as
  `trailing`; For You passes none, because a reader of someone else's
  request has nothing to act on.
  - For You sizes it to `screen width - 32`, which is exactly what a card
    gets in the Prayer Requests `ListView` (same 16pt side padding), and the
    section's height now comes from the card's own intrinsic height instead
    of `forYouPrimaryCardHeight`. That is why the carousel is a
    `SingleChildScrollView` + `Row` rather than a horizontal `ListView`: a
    lazy list needs a fixed height, which is the thing being removed. The
    set it builds — active, church-visible, unexpired — is small, so the
    lost laziness costs nothing.
- Model/provider/repository: `prayer_request_model.dart`,
  `prayer_providers.dart`, `prayer_repository.dart`.
- Data: `churches/{churchId}/prayer_requests` only.
  `globalPrayerRequests` still exists in Firestore with leftover documents,
  but `firestore.rules` now denies all reads and writes on it, so an older
  installed build that still tries to promote a request fails closed instead
  of writing into a collection nothing reads. The `isPrayerSourceOwner()`
  rules helper went with it.
- Backend: `notifyChurchAdminsOnPrayerCreated`,
  `notifyChurchMembersWhenPrayerVisible`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| PRAY-01 | Create with valid expiry | Request appears immediately in My Requests and persists. |
| PRAY-02 | Missing/past/>30-day expiry | Inline/modal validation is visible; no record is created. |
| PRAY-03 | Anonymous request | Member-facing/global cards do not expose identity. |
| PRAY-04 | Visible-to-church off/on | Off is absent from Pray for Others; on appears without refresh. |
| PRAY-05 | New request admin notification | Church admins receive one notification; tap opens For You/Pray for Others. |
| PRAY-06 | Visibility-enabled member notification | Members receive one notification when toggled on, not on unrelated edits. |
| PRAY-07 | Open the Prayer Requests screen as an admin | Exactly two scope boxes — My Requests and All Requests. No "Global" box, and no public/globe iconography anywhere on the screen. |
| PRAY-08 | Open a request's overflow menu | Only Edit (own requests) and Delete. No "Make global" / "Remove from global". |
| PRAY-09 | Open a request that was promoted globally before 2026-11-10 | It renders as an ordinary church request — no "Global request" badge, no source-church name under the title. |
| PRAY-10 | Delete a request that had been promoted globally | The church document is deleted and the write succeeds; no batched write to `globalPrayerRequests` is attempted. |
| PRAY-11 | Expiry boundary | Remaining days use calendar dates; the request remains through the selected date and disappears afterward. |
| PRAY-12 | Long multilingual content/detail modal | Content scrolls; no bottom overflow or duplicate handles. |
| PRAY-13 | Empty each scope | Common empty container/count/action is correct; no floating duplicate button. |
| PRAY-14 | Drawer count | Admins see the number of active church requests, everyone else their own. No de-duplication step is involved any more. |
| PRAY-15 | Studio → Sections → toggle "Pray for others" off | The For You section disappears live, with no app restart; `churches/{churchId}/for_you_section/prayForOthers` reads `enabled: false`. Toggling it back on restores the section just as live. |
| PRAY-16 | For You with no unexpired church-visible request | The Pray for others section renders nothing at all — no header, no empty card. Confirms the section is driven by content as well as by the Studio toggle. |
| PRAY-17 | Compare the same request on For You and on the Prayer Requests screen | Identical card: same width (both inset 16pt from each edge), same height, same icon tile, title, badges, 3-line description clamp and author/days-left footer. The only difference is the overflow menu, which appears on the Prayer Requests screen only. |
| PRAY-18 | For You with several church-visible requests | The section is one card tall and swipes horizontally between full-width cards; its height matches the tallest card rather than a fixed constant. |
