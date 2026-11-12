# About, Pastor and Footer

## Purpose

These features communicate church identity and trusted contact information
through member-facing About, Pastor and footer surfaces. Church admins manage
their data in Studio.

## About

- Stored at `churches/{churchId}/about/main`.
- Contains church name/title/tagline/description and related profile fields.
- Uses fetch-first plus stream updates so opening does not wait indefinitely.

## Pastor

- Stored as documents under `churches/{churchId}/pastor`.
- Supports multiple pastors, photos and one primary pastor.
- First pastor becomes primary. Setting a new primary updates all pastor flags
  and synchronizes top-level `church.pastorName`/`pastorPhoto`.
- Contact actions ask before opening dialer/email/maps.

## Footer

- Contacts:
  `churches/{churchId}/footerSupport/contacts/contactItems/{id}`.
- Social items:
  `churches/{churchId}/footerSupport/social/socialItems/{id}`.
- Items support active state and order; member pages show only applicable items.

### Desktop alignment

About and the pastor card go through `DesktopContentWidth` like the other
list screens, and everything inside shares one left edge. It previously had
**four**: the insight cards at the page gutter, the section headings a few
pixels off, "Our Pastors" a further 16 in because `PastorWidget` added its
own padding inside About's, and the pastor card ~78px beyond that again
because its carousel used `viewportFraction: 0.92`, which insets by a share
of the width.

`PastorWidget` now adds no padding of its own and its carousel fills the
page (`viewportFraction: 1.0`, no page gap — with one card on screen at a
time a gap is only ever visible mid-swipe).

`_PastorCard` measures from its constraints, not from
`MediaQuery.size.width`. Taken from the screen the avatar came out at 30%
of the whole window — about 444px on a desktop — inside a card capped far
narrower, which is what made it read as an enormous pale disc with the
pastor's details stranded beside it. It is now clamped to 72–132.

### Layout

Contacts and socials are laid out by one rule — `FooterActionTile` inside a
centred `FooterActionWrap`. Each tile is a fixed 96 wide with a circular
tinted icon above its label, so the two groups form an even grid at any
width and reflow onto a second line on a phone. A hairline divider separates
how to reach the church from where to follow it.

Previously the two groups followed different rules: contacts were `Expanded`
across the whole row, which on a desktop-width footer left three items
marooned in the corners, while the socials were a centred row with a fixed
20pt gap. `buildContacts` keeps its original `Expanded` behaviour, because
`DetailWidget` uses it in a narrow row where spreading is right.

**Social links are tappable.** They previously rendered an icon and a label
and carried a `url` that nothing ever opened. A tile whose stored URL is
missing, relative or not http(s) is left visibly inert rather than
pretending to be pressable.

## Technical map

- Member UI: `screens/side_drawer/about/`, `pastor_section.dart`,
  `screens/footer_sections/footer_section.dart`.
- Studio UI/repository: `studio_screen.dart`, `studio_repository.dart`.
- Repositories/providers: about, pastor and footer groups.
- Storage: church pastor-photo paths.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| PROFILE-01 | About empty/populated/update | Safe empty state; saved content updates member view. |
| PROFILE-02 | Create first pastor | Pastor is primary and church summary fields synchronize. |
| PROFILE-03 | Add/set another primary | Exactly one primary remains and member card changes. |
| PROFILE-04 | Update/delete pastor/photo | UI and Storage remain consistent; deleting primary has defined fallback. |
| PROFILE-05 | Contact confirmation | One action icon; confirm opens correct app, cancel stays. |
| PROFILE-06 | Footer contact/social CRUD | Active ordered items render correctly and disabled items disappear. |
| PROFILE-07 | Invalid external/contact data | Validation or safe launch failure; no crash. |
| PROFILE-08 | Church switch | Identity/contact data follows active church only. |
| PROFILE-09 | Long translated/user content | Cards wrap/scroll without clipping. |
| PROFILE-10 | Open the footer on a desktop-width browser window | Contacts and socials sit as two centred groups of equal tiles, not spread into the corners; a hairline divider separates them. |
| PROFILE-11 | Narrow the window to a phone width | Tiles reflow onto further lines and stay centred; no overflow and no clipped labels. |
| PROFILE-12 | Tap a social item with a valid http(s) URL | The link opens externally; a failure shows "Unable to open link" rather than doing nothing. |
| PROFILE-13 | Social item whose URL is empty, relative or non-http | The tile renders dimmed and does not respond to taps. |
| PROFILE-14 | Open About on a desktop window | Insight cards, both section headings, "Our Pastors" and the pastor card all start on the same left edge. |
| PROFILE-15 | Look at the pastor avatar on a desktop window | A portrait, not a disc filling a third of the card. |
