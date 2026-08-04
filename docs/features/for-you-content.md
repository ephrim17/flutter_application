# For You Content

## Purpose

For You assembles ordered, church-configurable spiritual content in one scroll.
Its registry currently includes Live Church, Daily Verse, Faith Engagement,
Bible Learning, Pray for Others, Featured For You, footer and Articles.

This document covers Daily Verse, Featured For You, Articles, Bible Swipe and
Reading Plans. Faith Engagement, Learning, Live Church and Prayer have separate
documents.

## Behaviour

- `churches/{churchId}/for_you_section/{sectionId}` controls enabled state and
  order. Studio controls Faith Engagement sub-items independently.
- Daily Verse uses a church-configured Bible book/chapter/verse reference and a
  plain card presentation.
- Featured For You is the consolidated featured/plans presentation.
- Articles are admin-authored, record `createdBy`/`updatedBy` footprints and
  show author details like feed cards. Tapping the author opens the common user
  card.
- A newly created article queues a notification to church members; tapping it
  opens the article destination.
- Bible Swipe content is versioned so configured verse changes can refresh
  local data.
- Reading-plan progress is scoped to church and user.

## Technical map

- Registry: `screens/for_you/for_you_screen.dart`.
- Sections: `screens/for_you/sections/`.
- Reading plans: `screens/for_you/reading_plan/`.
- Bible swipe: `screens/for_you/bible_swipe/`.
- Providers: `providers/for_you_sections/`.
- Repositories: `services/for_you_section/` and Studio repository.
- Article data: `churches/{churchId}/articles/{articleId}`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FORYOU-01 | Configure enabled/order values | Registry renders only enabled sections in exact order. |
| FORYOU-02 | Missing optional config | Documented default sections still render safely. |
| FORYOU-03 | Daily Verse reference | Correct verse loads; plain card has no gradient/overflow. |
| FORYOU-04 | Featured content empty/populated | Clean empty behaviour or equal-height content cards. |
| FORYOU-05 | Create article as admin | Article persists with creator footprint and member notification is queued. |
| FORYOU-06 | Article card/list/detail | Author avatar/details render; tapping opens common user card. |
| FORYOU-07 | Long article form/content | Text fields and reading view scroll above keyboard without overlap. |
| FORYOU-08 | Delete/update article | Stream updates once and notification is not duplicated on edit. |
| FORYOU-09 | Bible Swipe config version changes | Client refreshes configured verses and preserves stable navigation. |
| FORYOU-10 | Reading plan progress | Completed days persist for the same church/user and do not leak. |
| FORYOU-11 | Notification opens article | App lands on For You/article list from all lifecycle states. |
| FORYOU-12 | Section error | Other sections remain usable when one provider fails. |

