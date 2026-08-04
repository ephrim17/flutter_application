# Church Tree Product and Engineering Handbook

This handbook is the source of truth for how Church Tree features behave, who
can use them, where their data lives, and how each feature must be tested.
Documents describe the current production intent of the codebase; they are not
marketing copy.

## How to use this handbook

- Product and support teams: start with the purpose, roles, and user flows in
  each feature document.
- Engineers: use the technical map, data ownership, invariants, and failure
  behaviour before changing a feature.
- QA: execute the numbered test scenarios and record the build, platform,
  church, role, result, and evidence.
- Release owners: use the cross-feature release suite in
  [Testing Strategy](testing/README.md).

When behaviour changes, update the matching document and its test scenarios in
the same change. A feature is not complete when its documentation describes an
older flow.

## System documentation

- [System Architecture](architecture/system-architecture.md)
- [Testing Strategy and Release Gates](testing/README.md)
- [Feature Traceability Matrix](testing/feature-traceability.md)
- [Repository working rules](../AGENTS.md)
- [Developer-oriented app guide](../APP_GUIDE.md)

## Feature catalogue

| Area | Document | Primary roles | Status |
|---|---|---|---|
| Entry, authentication, password reset | [Authentication and Entry](features/authentication-and-entry.md) | Visitor, member, super admin | Active |
| Church discovery, registration, membership approval | [Churches and Membership](features/churches-and-membership.md) | Visitor, member, admin, super admin | Active |
| App shell, drawer, profile and preferences | [Navigation, Profile and Settings](features/navigation-profile-settings.md) | Member, admin | Active |
| Welcome, announcements, events, promise and prompts | [Home](features/home.md) | Member, admin | Active |
| Local/global posts, galleries, hashtags and moderation | [Feeds](features/feeds.md) | Member, admin | Active |
| Daily verse, featured content, articles and reading plans | [For You Content](features/for-you-content.md) | Member, admin | Active |
| Daily Faith and group Circles | [Faith Engagement](features/faith-engagement.md) | Member, admin | Active |
| Super-admin Bible courses and final exams | [Bible Learning](features/bible-learning.md) | Member, super admin | Active, church-disableable |
| YouTube live detection and playback | [Live Church](features/live-church.md) | Member, admin | Active, configurable |
| Personal, church-visible and global prayer requests | [Prayer Requests](features/prayer-requests.md) | Member, admin | Active |
| Directory, families, approval and church groups | [Members, Families and Groups](features/members-families-groups.md) | Member, admin | Active |
| Bible reader, downloads and saved verses | [Bible and Favorites](features/bible-and-favorites.md) | Member | Active |
| Cross-church social discovery | [Go Further](features/go-further.md) | Member, admin | Active |
| Church content and configuration management | [Studio](features/studio.md) | Church admin | Active, feature-flagged |
| Church health and engagement insights | [Dashboard](features/dashboard.md) | Church admin | Active, feature-flagged |
| Church inventory | [Equipment](features/equipment.md) | Church admin | Active, feature-flagged |
| Church identity and contact surfaces | [About, Pastor and Footer](features/about-pastor-footer.md) | Member, admin | Active |
| Push notifications, topics and deep links | [Notifications](features/notifications.md) | Member, admin | Active |
| Church lifecycle and global learning administration | [Super Admin](features/super-admin.md) | Super admin | Active |
| Deferred finance work | [Financial Dashboard](features/financial-dashboard.md) | None | Dormant / hidden |

## Documentation ownership

The engineer changing a feature owns the matching documentation update. QA
owns evidence and execution records. Product or the designated church operator
owns acceptance of changed business rules. Security-sensitive flows such as
authentication, authorization, global promotion, and password reset require a
negative-permission test before release.

