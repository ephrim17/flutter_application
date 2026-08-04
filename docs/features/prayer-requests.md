# Prayer Requests and Pray for Others

## Purpose

Members can submit personal prayer requests and optionally share them with their
church. Admins can manage all church requests and promote/unpromote a church
request globally. For You shows active church-visible requests as Pray for
Others.

## Views and rules

- Modern scope boxes show title and count for My Requests, All Requests
  (admin), and Global Requests.
- Request fields: title, description, anonymous flag, visible-to-church flag and
  required expiry date.
- Expiry must be today through 30 days from today. Validation appears inside
  the prayer modal, above any underlying screen.
- Members see/edit their own requests according to authorization. Admins can
  view all and toggle global state.
- Global promotion writes a linked copy to `globalPrayerRequests`; anonymous
  copies remove user identity. Unpromotion/deletion cleans the linked copy.
- Save with visible-to-church enabled notifies church members. New requests also
  notify church admins. Notification taps open For You at Pray for Others.
- Empty scopes use a common inline empty-state container and New Request action;
  there is no duplicate floating action button.

## Technical map

- UI: `screens/side_drawer/prayer_request_screen.dart`,
  `sections/pray_for_others_section.dart`.
- Model/provider/repository: `prayer_request_model.dart`,
  `prayer_providers.dart`, `prayer_repository.dart`.
- Data: `churches/{churchId}/prayer_requests`, `globalPrayerRequests`.
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
| PRAY-07 | Make/unmake global as admin | Local/global lists update immediately and linked data is correct. |
| PRAY-08 | Attempt global action as member | UI omits action and backend rejects direct request. |
| PRAY-09 | Edit promoted request | Linked global content and anonymity remain synchronized. |
| PRAY-10 | Delete promoted request | Local and linked global documents disappear. |
| PRAY-11 | Expiry boundary | Request remains through selected date and disappears afterward. |
| PRAY-12 | Long multilingual content/detail modal | Content scrolls; no bottom overflow or duplicate handles. |
| PRAY-13 | Empty each scope | Common empty container/count/action is correct; no floating duplicate button. |
| PRAY-14 | Drawer count | Unique local/global linked request is counted once. |

