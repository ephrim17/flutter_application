# Church Tree

Project guide:

- [APP_GUIDE.md](./APP_GUIDE.md)
- [Repository implementation rules](./AGENTS.md)

Quick start:

1. `flutter pub get`
2. `flutter run`

Tech stack:

- Flutter
- Riverpod
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Firebase Messaging

Engineering rule: user-visible church-app strings must be defined in
`defaultChurchTextContents` and rendered through `context.t(...)` or
`ref.t(...)`. Do not add raw UI strings in widgets, dialogs, snackbars, field
labels, empty states, or navigation labels. See `AGENTS.md` for the complete
architecture and implementation invariants.

Release verification:

1. `flutter analyze lib/church_app test`
2. `flutter test`
3. `npm --prefix functions run lint && npm --prefix functions run build`
4. `flutter build apk --release`
5. `flutter build ios --release --no-codesign`
6. `flutter build web --release`

Before publishing to either app store, replace the template
`com.example.flutter_application` / `com.example.flutterApplication` app IDs,
regenerate the matching Firebase application files, configure Android release
signing, and increment `version` in `pubspec.yaml`.
