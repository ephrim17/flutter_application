# Faith Engagement: Daily Faith and Circles

## Scope

Faith Engagement contains two independently controlled For You items:

- **Daily Faith**: a three-minute loop with Reflection, Prayer Points and Live
  It Out.
- **Circles**: group-scoped discussion spaces with text responses.

The former church Quiz Challenge is removed from member, Studio, notification
and dashboard surfaces.

## Daily Faith

- Admin creates dated reflections in Faith Engagement Studio.
- Reflection stores title/body, a Bible book/chapter/verse range, prayer points,
  Live It Out action, active date and enabled state.
- If there is no matching enabled reflection for today, the Daily Faith card is
  hidden.
- Progress contains three meaningful completion steps and is stored per
  user/day under church `faith_engagement`.
- Dashboard aggregates daily and seven-day completion updates.

## Circles

- Circle contains title, description, audience group, enabled state and order.
- Only members whose `churchGroupIds` includes the audience group can receive
  or view that circle. Admin authoring access is separate.
- Circle cards use circular visual treatment; opening a Circle is a full-screen
  push, not a modal.
- Responses contain user footprint and an absolute human-readable timestamp.
- A response notifies subscribed members of the circle's group topic except the
  author.

## Technical map

- UI: `sections/faith_engagement_section.dart`,
  `side_drawer/faith_engagement_studio_screen.dart`.
- Model/provider/repository: `faith_engagement_models.dart`,
  `faith_engagement_providers.dart`, `faith_engagement_repository.dart`.
- Data: `youth_circles` (legacy collection name), nested `responses`,
  `faith_reflections`, `faith_engagement`.
- Backend: `notifyCircleMembersOnResponseCreated` and notification queue.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| FAITH-01 | No reflection for current day | Daily Faith section is completely hidden. |
| FAITH-02 | Reflection with exact/ranged passage | Correct chapter and bounded verse range displays. |
| FAITH-03 | Complete three steps | Progress moves 0/3 to 3/3 and persists after relaunch. |
| FAITH-04 | Same user next day | A new daily record starts without altering prior history. |
| FAITH-05 | Missing prayer points/Live It Out in admin form | Validation prevents incomplete reflection. |
| FAITH-06 | Member belongs to target group | Circle appears and opens full screen. |
| FAITH-07 | Member not in target group | Circle cannot be read through UI/provider; backend access is denied. |
| FAITH-08 | Group membership changes while signed in | Topic subscription and visible circle list update. |
| FAITH-09 | Add response | Message and absolute timestamp appear once. |
| FAITH-10 | Response notification | Other subscribed group members receive it; author does not. |
| FAITH-11 | Delete response/circle | Authorized deletion updates stream; nested responses are cleaned. |
| FAITH-12 | Reorder/disable Daily Faith and Circles | For You reflects independent sub-item controls. |
| FAITH-13 | Dashboard updates | Daily and seven-day metrics match underlying progress records. |

