# Church Tree App Guide

## What This App Is

This project is a Flutter-based church platform with 3 main operating modes:

1. Normal member flow
2. Church admin flow
3. Super admin flow

The app supports:

- church selection
- user login and registration
- church-specific content
- member approval and directory
- feeds
- Studio content management
- super admin church setup and maintenance

## High-Level User Flows

### 1. Entry Flow

Main entry files:

- `lib/church_app/screens/entry/app_bootstrap.dart`
- `lib/church_app/screens/entry/app_entry.dart`
- `lib/church_app/screens/entry/create_auth_account_screen.dart`
- `lib/church_app/screens/select-church-screen.dart`

Typical flow:

1. App starts
2. Firebase auth state is checked
3. If no user is signed in, user sees auth screens
4. If signed in but no church is selected, user sees church selection
5. If signed in and a church is selected, app loads church-scoped user data
6. Based on user state, app shows:
   - church app
   - pending approval screen
   - admin mode maintenance screen
   - super admin mode chooser

### 2. Church Selection

Main file:

- `lib/church_app/screens/select-church-screen.dart`

This screen shows:

- `Your Churches`
- `Other Churches`

Behavior:

- `Your Churches` is derived from the signed-in user's membership under each church's `users` subcollection
- `Other Churches` shows churches the user is not yet part of
- selecting a church either:
  - opens the church directly if user already belongs to it
  - takes the user into request-access flow

### 3. Login / Request Access

Main files:

- `lib/church_app/screens/entry/login_entry_screen.dart`
- `lib/church_app/screens/entry/login_request_screen.dart`
- `lib/church_app/services/firestore/firestore_authentication.dart`

Important behavior:

- login uses Firebase Auth
- church membership is checked in `churches/{churchId}/users/{authUid}`
- request-access creates a church user record
- approval is stored on the church user doc via `approved: true/false`

Special first-user rule already implemented:

- if a church has no users yet
- and `config/app.admins` has exactly one matching email
- that first matching user can be auto-approved

## Roles

### 1. Member

A member is a normal church user stored under:

- `churches/{churchId}/users/{uid}`

Important fields:

- `name`
- `email`
- `role`
- `approved`
- `churchGroupIds`

### 2. Church Admin

Church admins are verified per church using:

- `churches/{churchId}/config/app`
- field: `admins: []`

This is email-based and church-scoped.

### 3. Super Admin

Super admins are verified globally using:

- top-level collection: `superAdmins`

Current verification rule:

- signed-in user's email is matched against a document in `superAdmins`
- `enabled` must be `true`

Expected structure:

- `superAdmins/{anyDocId}`
  - `email: "admin@example.com"`
  - `enabled: true`

Main provider:

- `lib/church_app/providers/authentication/super_admin_provider.dart`

## Main App Areas

### Home

Main files:

- `lib/church_app/screens/home/home_screen.dart`
- `lib/church_app/screens/home/sections/announcement_section.dart`
- `lib/church_app/screens/home/sections/events_section.dart`
- `lib/church_app/screens/side_drawer/pastor_section.dart`

Home is driven by configurable section data stored per church.

### For You

Main files:

- `lib/church_app/screens/for_you/for_you_screen.dart`
- `lib/church_app/screens/for_you/sections/daily_verse_section.dart`
- `lib/church_app/screens/for_you/sections/article_section.dart`
- `lib/church_app/screens/for_you/sections/reading_plan_section.dart`
- `lib/church_app/screens/for_you/bible_swipe/bible_verse_swipe_screen.dart`

This area includes:

- daily verse
- promise verse
- articles
- featured content
- reading plans
- bible swipe verses

### Feeds

Main files:

- `lib/church_app/screens/feed_screen.dart`
- `lib/church_app/widgets/feed_card_widget.dart`
- `lib/church_app/widgets/feed_post_modal.dart`

Feeds are church-based social-style posts.

### Side Drawer

Main files:

- `lib/church_app/screens/church_side_drawer.dart`
- `lib/church_app/screens/side_drawer/about_screen.dart`
- `lib/church_app/screens/side_drawer/members_screen.dart`
- `lib/church_app/screens/side_drawer/church_groups_screen.dart`
- `lib/church_app/screens/side_drawer/event_screen.dart`
- `lib/church_app/screens/side_drawer/prayer_request_screen.dart`
- `lib/church_app/screens/side_drawer/settings_screen.dart`
- `lib/church_app/screens/side_drawer/studio_screen.dart`

## Studio

Main files:

- `lib/church_app/screens/side_drawer/studio_screen.dart`
- `lib/church_app/services/studio/studio_repository.dart`

Studio is the church-level content and configuration workspace.

Current sections include:

- Theme
- About
- Pastor
- Footer
- Announcements
- Events
- Articles
- Daily Verse
- Promise
- Bible Swipe
- Sections
- Notifications
- Prompt
- Admin Mode
- Admins

### Important Studio Behavior

- all Studio writes are scoped to the current `churchId`
- Studio uses church config, church collections, and church subcollections
- About and Footer use fetch-first behavior before live stream updates
- Sections support drag-and-drop ordering
- Bible Swipe increments `features.bibleSwipeVersion`

### Admin Mode

Admin mode is church-scoped and stored in:

- `churches/{churchId}/config/app`
- field: `adminMode.enabled`

Behavior:

- if enabled, non-admin users see a maintenance-style screen
- church admins still pass through
- tapping `Okay` takes regular users back to church selection without logging them out

Main file:

- `lib/church_app/screens/entry/admin_mode_screen.dart`

## Super Admin Flow

Main files:

- `lib/church_app/screens/super_admin/super_admin_mode_screen.dart`
- `lib/church_app/screens/super_admin/super_admin_home_screen.dart`
- `lib/church_app/screens/super_admin/create_church_screen.dart`
- `lib/church_app/services/super_admin/super_admin_church_service.dart`

Super admin can:

- create churches
- edit churches
- enable/disable churches
- choose between normal flow and super admin flow

### Church Creation

Church creation supports:

- church name
- pastor name
- address
- contact
- email
- logo
- pastor photo
- enabled toggle
- optional initial account setup

If account setup is enabled:

- Firebase Auth admin account is created
- password setup email is sent

If account setup is disabled:

- Firebase Auth admin account is skipped
- church bootstrap still happens
- initial admin email can still be stored in church config

### Church Bootstrap

When a church is created, starter data is seeded under that church:

- app config
- about doc
- footer support docs
- footer contact items
- home sections
- for-you sections
- bible swipe starter verses
- church groups
- seeded pastor doc

## Pastor Flow

Relevant files:

- `lib/church_app/screens/side_drawer/pastor_section.dart`
- `lib/church_app/services/home_section/pastors_repository.dart`
- `lib/church_app/services/studio/studio_repository.dart`
- `lib/church_app/models/home_section_models/pastor_model.dart`

Current behavior:

- pastors are stored as documents in `churches/{churchId}/pastor`
- pastor images are stored in Firebase Storage under:
  - `churches/{churchId}/pastorPhotos/...`
- first pastor gets `primary: true`
- Studio can manually switch which pastor is main
- when a pastor is marked main, church-level fields are also updated:
  - `churches/{churchId}.pastorName`
  - `churches/{churchId}.pastorPhoto`

UI behavior:

- pastor card uses primary + secondary gradient
- shows circular pastor photo
- shows contact chip with call action
- shows `Main` chip if `primary == true`

## State Management

This app mainly uses Riverpod.

Important provider groups:

- auth providers
- church selection providers
- app config providers
- member providers
- Studio/config providers
- home and for-you providers

Examples:

- `lib/church_app/providers/user_provider.dart`
- `lib/church_app/providers/app_config_provider.dart`
- `lib/church_app/providers/church_provider.dart`
- `lib/church_app/providers/select_church_provider.dart`

## Firestore Structure Overview

Top-level collections commonly used:

- `churches`
- `users`
- `globalFeeds`
- `superAdmins`

### Per Church

Typical structure:

- `churches/{churchId}`
  - main church doc
  - `config/app`
  - `about/main`
  - `users/{uid}`
  - `announcements/{id}`
  - `events/{id}`
  - `articles/{id}`
  - `pastor/{id}`
  - `groups/{groupId}`
  - `groups/{groupId}/users/{memberId}`
  - `home_sections/{id}`
  - `for_you_section/{id}`
  - `footerSupport/contacts/contactItems/{id}`
  - `footerSupport/social/socialItems/{id}`
  - `bibleRandomSwipeVerses/swipeVerses`
  - `notification_requests/{id}`

### Important Church Doc Fields

On `churches/{churchId}`:

- `name`
- `pastorName`
- `pastorPhoto`
- `address`
- `contact`
- `email`
- `logo`
- `enabled`

### Important App Config Fields

On `churches/{churchId}/config/app`:

- `admins`
- `features`
- `dailyVerse`
- `promiseWord`
- `promptSheet`
- `adminMode`
- `theme`
- `textContent`
- `churchLogo`

## Storage Structure Overview

Important Firebase Storage paths:

- `churches/{churchId}/logo`
- `churches/{churchId}/pastorPhotos/...`
- `churches/{churchId}/announcements/...`

## File Map By Responsibility

### Entry and Routing

- `lib/church_app/screens/entry/`

### Church Selection

- `lib/church_app/screens/select-church-screen.dart`

### Home

- `lib/church_app/screens/home/`

### For You

- `lib/church_app/screens/for_you/`

### Side Drawer Features

- `lib/church_app/screens/side_drawer/`

### Super Admin

- `lib/church_app/screens/super_admin/`

### Services

- `lib/church_app/services/`

### Providers

- `lib/church_app/providers/`

### Models

- `lib/church_app/models/`

### Reusable Widgets

- `lib/church_app/widgets/`

## Key Things To Remember

1. Most app data is church-scoped.
2. Church admin is not the same as super admin.
3. `approved` is checked from the church user doc tied to the signed-in auth UID.
4. Studio changes should stay scoped to the active church.
5. Admin mode blocks regular users per church, not globally.
6. Super admin access is global and email-based through the `superAdmins` collection.

## Recommended Starting Points For New Developers

If you are new to this codebase, start here:

1. `lib/church_app/screens/entry/app_entry.dart`
2. `lib/church_app/screens/select-church-screen.dart`
3. `lib/church_app/providers/app_config_provider.dart`
4. `lib/church_app/screens/side_drawer/studio_screen.dart`
5. `lib/church_app/services/studio/studio_repository.dart`
6. `lib/church_app/screens/super_admin/create_church_screen.dart`
7. `lib/church_app/services/super_admin/super_admin_church_service.dart`

## Dependencies

Important packages from `pubspec.yaml`:

- `firebase_core`
- `cloud_firestore`
- `firebase_auth`
- `firebase_storage`
- `firebase_messaging`
- `flutter_riverpod`
- `hooks_riverpod`
- `image_picker`
- `url_launcher`
- `shared_preferences`

## Summary

This app is a church platform where:

- users belong to one or more churches
- each church has its own content, members, pastors, and configuration
- Studio manages church-specific content
- super admin manages churches globally
- access control is split between:
  - global super admin
  - church-scoped admin
  - church member approval

This guide is intended to make the project easier to understand quickly before making changes.
