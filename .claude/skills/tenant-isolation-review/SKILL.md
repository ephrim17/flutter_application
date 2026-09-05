---
name: tenant-isolation-review
description: Reviews code changes for church-scoping / multi-tenant isolation violations — the app's core invariant that every read/write must carry the correct churchId and that church-admin and super-admin authority are never inferred from each other. Use when reviewing a diff or PR that touches Firestore/Storage queries, security rules, admin/authorization logic, or church-scoped repositories, or when asked to check for tenant leakage.
---

Review the target code for violations of this app's multi-tenant isolation model.

This app is a multi-tenant Flutter/Firebase church platform: a user may belong
to multiple churches, but all church data must stay scoped to
`churches/{churchId}/...` except the explicit global collections
(`globalFeeds`, `globalPrayerRequests`, global `learning_modules`,
`superAdmins`, top-level `users`). A real cross-tenant Storage-rules gap was
already found in this app (any authenticated user could read/write arbitrary
church paths) — treat this class of bug as high severity.

## Scope

Default to reviewing the current uncommitted + staged diff (`git diff HEAD`).
If `$ARGUMENTS` names a PR number, branch, or path, review that instead.

## Checklist

For every changed Firestore/Storage read, write, query, or security rule, and
every authorization check, verify:

1. **churchId scoping** — every `churches/{churchId}/...` read/write carries
   an explicitly resolved `churchId` (from the current selected-church
   state), never hardcoded, omitted, or reused from a different/stale church
   context.
2. **Firestore path construction** — new Firestore paths go through
   `lib/church_app/services/firestore/firestore_paths.dart` rather than
   inline path strings, where that module covers the collection.
3. **Admin authority separation** — church-admin status (email match in
   `churches/{churchId}/config/app.admins`) and super-admin status (global
   `superAdmins` record with `enabled: true`) are never inferred from one
   another, and neither is inferred from plain membership/approval.
4. **Server-side enforcement** — any privileged mutation (global
   promotion/un-promotion, admin actions, super-admin actions, admin-only
   writes) is enforced by Firestore/Storage security rules or a Cloud
   Function callable, not only by hiding the control in the UI.
5. **Storage path scoping** — Storage reads/writes/deletes use the
   `churches/{churchId}/...` (or documented global) prefix, and deleting a
   record deletes its owned Storage objects.
6. **Church-switch cleanup** — providers/streams/listeners scoped to the
   previous church are disposed or invalidated on church switch, so no stale
   cross-church data can leak into the new context.
7. **Global copy consistency** — global copies of church content (promoted
   feed posts, promoted prayer requests) retain source church/document IDs so
   promotion, edits, and removal keep both sides in sync.

## Output

List findings most-severe first. For each: file:line, which checklist item it
violates, and a concrete failure scenario (what data leaks to whom, under
what action). If nothing violates the checklist, say so plainly rather than
inventing minor nits.
