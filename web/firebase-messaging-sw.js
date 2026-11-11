// Background push for the web build.
//
// `firebase_messaging` registers this file by name at the site root; the
// name is fixed by the SDK and cannot be changed. Without it the browser has
// nowhere to deliver a push to while the tab is closed or in the background,
// so `getToken()` fails and the web app is simply unreachable — which is why
// web push was off until now, not because the platform cannot do it.
//
// This file runs in a service worker, outside the Flutter app: no bundler,
// no modules, hence the compat builds loaded over the network. The config
// below is the same web app config as `lib/firebase_options.dart`; these
// values are public identifiers, not secrets (they ship in every web build
// already), but they must be kept in step with that file by hand.
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyDpCdWKenqttG6gI4h5pG1FRthWzLbCNBU',
  appId: '1:527118580197:web:813d4a31d13b20f586d70c',
  messagingSenderId: '527118580197',
  projectId: 'flutterlearning-c9f6c',
  authDomain: 'flutterlearning-c9f6c.firebaseapp.com',
  storageBucket: 'flutterlearning-c9f6c.firebasestorage.app',
  measurementId: 'G-LHP0822YM8',
});

// Every push this app sends carries a `notification` block (see
// `sendToUids` in functions/src/notify.ts), and the SDK's own handler
// displays those automatically. Registering messaging is therefore all that
// background display needs — an `onBackgroundMessage` handler here would
// only matter for data-only payloads, and adding one that also calls
// `showNotification` would show every notification twice.
firebase.messaging();
