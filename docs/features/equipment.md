# Equipment

## Purpose and access

Equipment is a church inventory dashboard for admins. It is shown only when the
user is a church admin and `equipmentEnabled` is true. Drawer badge count shows
the current number of equipment records.

## Data and operations

Each `churches/{churchId}/equipments/{equipmentId}` record includes name,
category, condition/health, location, description, purchase date, amount,
optional bill URL/file name and timestamps.

Admins can:

- review total/category/location/recent summaries;
- search, filter by category and condition, and sort;
- create, edit and delete equipment;
- upload, view and share an optional bill image.

Bill files are owned by the equipment feature in Firebase Storage and should be
removed/replaced with the corresponding record lifecycle.

## Technical map

- UI/state: `equipment_screen.dart`, `equipment_viewmodel.dart`,
  `equipment_view_state.dart`.
- Model/repository: `equipment_item_model.dart`, `equipment_repository.dart`.
- Data: `churches/{churchId}/equipments` and feature-owned Storage paths.

## Test flows

| ID | Scenario | Expected result |
|---|---|---|
| EQUIP-01 | Member/admin/feature flag | Only enabled church admin can open or mutate inventory. |
| EQUIP-02 | Add valid equipment | Record appears once; summaries and drawer count update. |
| EQUIP-03 | Required/invalid amount/date | Inline validation prevents write. |
| EQUIP-04 | Upload/view/share bill | Image uploads, previews and shares; failure preserves form. |
| EQUIP-05 | Edit/replace bill | Fields update and obsolete owned file is handled. |
| EQUIP-06 | Delete equipment | Confirmation appears; record and owned bill are removed. |
| EQUIP-07 | Search/filter/sort | Combined controls return correct stable order and clear correctly. |
| EQUIP-08 | Empty/loading/error | Useful state, no endless spinner and retry works. |
| EQUIP-09 | Church switch | Inventory and count fully re-scope. |
| EQUIP-10 | Long values/small device | Cards, details and editor remain scrollable without overflow. |

