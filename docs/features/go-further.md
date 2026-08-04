# Go Further

## Purpose

Go Further helps users discover enabled churches that publish Facebook,
Instagram or YouTube links. It is cross-church discovery, not a membership or
content-sharing surface.

## Behaviour

- Results are paginated and filtered to churches with at least one supported
  social presence.
- Search filters the loaded/discoverable list and pagination continues when
  needed to find matches.
- Pull-to-refresh reloads the catalogue and current church.
- Current-church admins can add/edit their church's social discovery details.
- External social links use the common confirmation/launcher behaviour.
- Selecting discovery content never changes active church membership silently.

## Technical map

- UI: `screens/go_further_screen.dart`.
- Provider: `providers/go_further_provider.dart`.
- Church data: top-level `churches/{churchId}` social fields.
- Common launch confirmation: `helpers/contact_launcher.dart`.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| GO-01 | Initial pagination | Only enabled churches with social links appear once. |
| GO-02 | Scroll near end | Next page loads without duplicate/gap. |
| GO-03 | Search loaded/future page | Matching church appears or clear empty state is shown. |
| GO-04 | Pull to refresh | Updated church/social data replaces stale list. |
| GO-05 | Current admin adds links | Church becomes discoverable; other church records are untouched. |
| GO-06 | Member attempts edit | Edit affordance is absent and backend rejects mutation. |
| GO-07 | Tap social link | Confirmation appears; cancel stays in app; confirm opens correct app/browser. |
| GO-08 | Network/empty list | Recoverable localized state; no endless spinner. |

