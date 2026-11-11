# Communication

## Purpose

Church staff reaching the congregation by WhatsApp, SMS, email or a call
list, with a record of what went out.

Modelled on [ShepherdDesk](https://tcsong.com/shepherddesk/#messages). What
was taken and what was deliberately left out is in [Scope](#scope-v1).

## Views and rules

- **The app never sends.** It opens WhatsApp, the SMS app or the mail app
  with the message already written, and a person presses send there. This is
  the design, not a limitation: the message arrives from the number members
  already recognise, it works for members who never installed the app, and
  nothing can go out by accident.
- **"Log as sent" is the church's own record**, not delivery confirmation.
  The app hands off and cannot know whether send was pressed. The log
  answers "did anyone tell the youth group?", which is the question actually
  asked.
- **Staff only, and it replaced the Community tab.** `CommunityFeedScreen`
  and its providers are untouched in the code and commented out in
  `church_tab_screen.dart`; restoring the tab is re-enabling those lines. A
  member now sees Home and For You.
- **Recipients are approved members the chosen channel can actually
  reach** — a dialable phone for WhatsApp or SMS, an address for email.
  Anyone else is counted and named in the summary ("4 have nothing on file
  for this") rather than silently dropped, because a sender who thinks they
  reached 40 people and reached 36 has been misled.
- **A message naming the person cannot be sent to a group.** `{name}` and
  `{first}` differ per person; one body goes to everyone. When they are
  present the group buttons are disabled and each recipient row offers its
  own send, which is how WhatsApp works anyway. One tap strips the names out
  if a group message was what was wanted.
- **Every channel has one primary action**, so a chosen list of recipients
  leads somewhere. SMS and email open one hand-off for the whole list;
  WhatsApp has no such link, so its button walks the list — "Open chat 3 of
  8" — opening the next person who has not been opened yet and ticking each
  off as it goes. Without it the recipient list just sat there and the only
  way through was tapping each row, which does not read as "now send it".
- **Copy numbers was removed.** Copy message and Log as sent are the two
  secondary actions; a bare list of phone numbers had no use once the
  per-person and per-batch hand-offs existed.
- **Email recipients go in bcc**, never to — a church announcement must not
  hand every member's address to every other member.

## Reaching more people than one hand-off can carry

The limits are not the app's — they are on the other side of the hand-off,
and they differ sharply by channel. Measured on the emulator and by URL
length, with a typical 117-character message:

| Recipients | `sms:` URI | `mailto:` URI |
|---|---|---|
| 18 | 404 | 641 |
| 100 | 1,470 | 2,691 |
| 200 | 2,770 | 5,191 |
| 500 | 6,670 | 12,691 |

- **SMS is generous.** Google Messages on Android accepted 200, 500 and
  1,000 recipients in testing (a 13,000-character URI) and showed "Mass
  text — each recipient will get an SMS message from you. Replies will
  appear in individual conversations". That is exactly right for a church:
  individual messages, individual reply threads, not a group chat. But that
  is one app on one OS; other SMS apps, iOS and individual carriers cap
  recipients, and a carrier that drops the overflow **gives no error**. The
  app therefore splits above 100 rather than trusting it.
- **Email is capped by URL length, not by the mail app.** Many clients
  truncate a `mailto:` around 2,000 characters, silently. At 200 bcc
  addresses the URL is over 5,000. Split above 50.
- **WhatsApp has no bulk link at all.** `wa.me` opens exactly one chat, so
  one recipient per hand-off is the ceiling, not a setting. Reaching a large
  group for free means a Broadcast List created inside WhatsApp (256
  recipients), which is what "Copy numbers" is for. Bulk sending through the
  WhatsApp Business Cloud API needs an approved Meta business account,
  pre-approved templates and a per-message fee — the reference treats it as
  optional setup for the same reason.

Above the per-channel ceiling the composer shows a **batch stepper**: the
list is split, each batch has its own Open button, and batches already
opened are ticked. Batch membership is stable across rebuilds, and progress
is remembered within the session, so a long run is resumed rather than
restarted — sending the same notice to the same people twice is the one
mistake that cannot be taken back. Below the ceiling nothing changes and it
stays a single button.

`communicationBatchLimit` holds the three numbers, with the reasoning in its
doc comment.

## Adding a WhatsApp group

**A group's invite link cannot be generated from its name.** The code in
`chat.whatsapp.com/<code>` is a secret WhatsApp issues per group, with no
public lookup and no relation to the name — two groups can share a name,
and anyone holding a code can join. It has to come from WhatsApp itself:
Group info → Invite via link → Copy link.

What the app does instead is remove the typing. Whoever adds a group has
just copied that link, so the dialog reads the clipboard: a valid group
link fills the box on open, there is a Paste button to do it again, and a
link pasted into the *name* box is moved to the link box rather than
failing validation later. A clipboard holding anything else is ignored, so
the field is never silently filled with the wrong thing — and a `wa.me`
link is refused, because that is one person, not a group.

## Header and small screens

The screen carries **no title or description of its own**. The tab the
reader pressed is already called Messages and the segmented control says
which part they are in, so a heading plus a line of explanatory text only
pushed the compose form further down every time the tab was opened.

The four statistics are one wrapping line of pills — number and short label
on a single line — rather than boxes. As boxes they were two deep on a
phone, roughly 140dp of standing furniture above a form people come here to
type in; they are reference, not the task. Pills size to their own content
and wrap like words, so nothing is squeezed and nothing scrolls out of
reach.

The old boxes split an equal share of the row between four chips, which at
320dp gave each about 70dp and broke "Messages this month" mid-word into
"Messag / es this". The short labels (`communication.stat_*_short`) and the
content sizing both exist so that cannot recur. Verified at 393×852
(iPhone 16) 2026-11-11.

## Groups

Recipients can be narrowed to one church group (`churchGroupDefinitions`,
matched against each member's `churchGroupIds`) or left as Everyone. An
empty group yields an empty recipient list, never a silent fallback to
everyone — a message meant for the youth must not reach the whole church
because nobody has been added to the group yet.

## Phone numbers

`normalizePhoneNumber` reduces whatever was typed to a dialable number:
punctuation is dropped, `+`/`00` prefixes are understood, a leading trunk
`0` is replaced by the country code, and a bare local number gets the
country code added (default `91`). Anything under ten digits is treated as
not dialable rather than being turned into a `wa.me` link that opens a chat
with a stranger. Fully unit-tested — this is the part that fails quietly.

## Scope (v1)

Taken from ShepherdDesk: the channels, the message categories, the
template library, the placeholder syntax, the sent log, the headline stats,
and the hand-off model itself.

Deliberately **not** built:

- **A call list channel.** The reference has one; the owner asked for
  WhatsApp, SMS and email only. The member directory already carries phone
  numbers for calling.

- **Announcements.** The app already has these in Studio; the owner asked
  for them to stay there.
- **Per-member opt-out by category.** The reference lets members opt out per
  category. That needs member-facing settings, and with a hand-off model
  there is no delivery step that could honour it. The category is recorded
  on each logged message so history reads by purpose, but it does not filter
  anyone out. Do not describe it to a church as an opt-out until that exists.
- **WhatsApp Business (Meta Cloud API).** The reference calls it optional
  and uses it only to send to many members at once while online. Everyday
  use works without it.
- **Push notification.** The app can genuinely send push and already does
  for prayers, articles and live services. Communication deliberately does
  not: the owner chose hand-off only, so this reaches members who never
  installed the app, which push cannot.

## Technical map

- Screen: `screens/communication/communication_screen.dart` — Compose,
  History, Templates.
- Logic: `helpers/message_composer.dart` — placeholder resolution, phone
  normalisation, reachability, stats, and the `wa.me` / `sms:` / `mailto:`
  builders. Pure and fully unit-tested
  (`test/message_composer_test.dart`).
- Model: `models/communication_models.dart` — `MessageChannel`,
  `messageCategoryKeys`, `MessageTemplate`, `SentMessage`.
- Repository/providers: `services/side_drawer/communication_repository.dart`,
  `providers/side_drawer/communication_providers.dart`.
- Data: `churches/{churchId}/message_log/{id}` (capped at 300 on the client)
  and `churches/{churchId}/message_templates/{id}`.
- Launching: `helpers/contact_launcher.dart`, which already confirms before
  opening a phone or mail app.

**Channels and categories are stored as keys**, not display text, with
matching `communication.channel.<key>` and `communication.category.<key>`
entries in `defaultChurchTextContents`. Because those keys are built at
runtime, `text_content_policy_test.dart` cannot see them in the source and
checks both sets by value instead.

## Deployment

`firestore.rules` gained `message_log` and `message_templates` matches, both
`isChurchStaff(churchId)` for read as well as write. Deploy with
**`firebase deploy --only firestore`** — never `--only firestore:rules`,
which reports success and releases nothing against this project's
array-form multi-database config. Until it is deployed the History and
Templates tabs fail to load; Compose still works, since it only reads
members.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| COM-01 | Open the app as a church admin | A "Messages" tab replaces Community. |
| COM-02 | Open the app as an approved member | Only Home and For You. Reading `message_log` directly is denied. |
| COM-03 | Pick WhatsApp with members who have no number | The summary says how many cannot be reached; they are not listed as recipients. |
| COM-04 | Switch channel to Email | The recipient list changes to members with an address; the per-row button becomes mail. |
| COM-05 | Type a message with `{first}` and look at the group buttons | They are disabled, with an explanation and a "Remove names" action. |
| COM-06 | Tap "Remove names" on "Dear {name}, we meet at 9." | Becomes "Dear, we meet at 9." — no stray space before the comma. |
| COM-07 | Send to one person on WhatsApp | WhatsApp opens on that person's chat with their name filled in. |
| COM-08 | Use "Open SMS to everyone" | The SMS app opens addressed to every reachable member, message pre-filled. |
| COM-09 | Use "Open email to everyone" | Addresses are in bcc, not to. |
| COM-11 | Tap "Log as sent" | The History tab shows it with channel, category, recipient count and time. |
| COM-12 | Save a template, then tap it in Compose | The body and category fill in. |
| COM-13 | Delete a template | It disappears; history entries already logged are unaffected. |
| COM-14 | A member stored as `09876543210` | Reached once, as `919876543210` — not skipped and not double-counted. |
| COM-15 | Deselect a recipient, then reselect | They drop out of the count and come back without rebuilding the selection. |
| COM-16 | Pick a group from the Which group dropdown | Only that group's members are listed, and the reachable count follows. |
| COM-17 | Pick a group nobody belongs to | Zero recipients, and the send actions are disabled — never a fallback to everyone. |
| COM-18 | Choose SMS with more than 100 reachable members | The single "Open SMS to everyone" is replaced by a batch stepper; each batch ticks once opened. |
| COM-19 | Open batch 1, leave, come back | Batch 1 is still ticked and the same people are still in it. |
| COM-20 | Choose Email and check the subject line | Reads "<church> — <chosen subject>". |
| COM-21 | Choose a template from the dropdown | The message body and the subject both fill in. |
| COM-22 | Open the tab on a 320dp phone | The four statistic pills wrap onto further lines and every label reads in full, with no mid-word break. |
| COM-30 | Open the Messages tab at 393x852 (iPhone 16) | No screen heading or description; the stat strip is one or two lines of pills and the compose form starts near the top. |
| COM-23 | Copy a group's invite link in WhatsApp, then tap Add group | The link box is already filled, with "Link filled in from your clipboard". |
| COM-24 | Tap Add group with something else on the clipboard | Both boxes are empty; nothing is guessed. The Paste button explains where to get the link. |
| COM-25 | Paste the invite link into the Group name box | It moves to the link box and asks for a name. |
| COM-26 | Choose WhatsApp with 8 recipients and write a message | A primary "Open chat 1 of 8" button appears; each press opens the next unopened person. |
| COM-27 | Open three chats, then look at the list | Those three rows show a tick, the button reads "Open chat 4 of 8", and leaving the tab and coming back does not lose the count within the sitting. |
| COM-28 | Open every chat | The button becomes "All 8 chats opened" and is disabled. |
| COM-29 | Change the group or the channel mid-send | The progress resets, because the recipient list it was counting through has changed. |
