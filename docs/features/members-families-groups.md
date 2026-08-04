# Members, Families and Church Groups

## Purpose

The member directory represents church-scoped people, approval status,
families, special days and ministry groups. Admins manage records; approved
members can browse permitted directory/group views.

## Member and family rules

- Member records live at `churches/{churchId}/users/{uid}` and contain identity,
  contact, demographic, family, church-record and group fields.
- Admin can create a member with an Auth email/account path or a record without
  email, then edit, approve or delete according to authorization.
- Directory tabs provide All, Families, Individuals and Special Days.
- Gender snapshot boxes open a separate filtered member page rather than
  expanding a long list inside the dashboard.
- Gender and marital status use the shared rounded field design.
- Married selection exposes Family ID. An individual may select an existing
  family ID but cannot create a new family through that path.
- Birthday and anniversary sections derive from DOB/wedding date.

## Church groups

- Group definitions: `churches/{churchId}/groups/{groupId}`.
- Membership records: nested `groups/{groupId}/users/{uid}` plus normalized
  `churchGroupIds` on the church user.
- Adding/removing a user must keep both representations synchronized.
- Group membership controls Circle visibility and group notification topics.

## User quick card and contact actions

Feed/article/member surfaces use the common user card. It displays one phone
action only. Phone, email and map actions show a confirmation dialog before
launching another app.

## Technical map

- UI: `members_screen.dart`, `church_groups_screen.dart`,
  `dashboard_gender_members_screen.dart`, `user_quick_card_widget.dart`.
- Providers/services: `members_provider.dart`, `members_repository.dart`,
  `church_group_members_provider.dart`, `church_user_repository.dart`.
- Model: `app_user_model.dart`, church group member model.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| MEMBER-01 | Load/search/filter directory | Correct church members and counts appear; search is case-insensitive. |
| MEMBER-02 | Create with email/without email | Correct record/account path occurs once. |
| MEMBER-03 | Approve pending member | Access updates and metric/notification side effects occur once. |
| MEMBER-04 | Edit demographics/church records | Valid data persists; optional fields render Not provided. |
| MEMBER-05 | Married vs individual family rules | Married can use family workflow; individual can choose existing but not create new. |
| MEMBER-06 | Family grouping | Members group under correct family; unknown IDs are handled safely. |
| MEMBER-07 | Birthday/anniversary boundary | Correct local-date members appear in Special Days. |
| MEMBER-08 | Tap Male/Female snapshot | Separate page contains all and only selected gender; search works. |
| MEMBER-09 | Add/remove group member | Nested membership and `churchGroupIds` stay synchronized. |
| MEMBER-10 | Circle/topic after group change | Visibility and subscription update without leaking old group content. |
| MEMBER-11 | Common user card | One phone icon; call/email/map require confirmation and cancellation works. |
| MEMBER-12 | Delete member | Confirmation appears; only target church record/dependent intended data changes. |
| MEMBER-13 | Non-admin mutation attempt | UI hides controls and backend rejects direct mutation. |
| MEMBER-14 | Large directory/pagination/scroll | Smooth list, no clipped cards and no duplicate entries. |

