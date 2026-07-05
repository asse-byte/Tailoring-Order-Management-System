# Platform setup — Android & iOS

These are the manifest / Info.plist entries the app needs for the features built
across Steps 1–8. Apply them once after you generate the native folders with
`flutter create . --platforms=android,ios …`.

---

## 🤖 Android

### `android/app/src/main/AndroidManifest.xml`

Inside the `<manifest>` tag (above `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- FCM heads-up notifications on Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- image_picker camera access (gallery picks don't need this) -->
<uses-permission android:name="android.permission.CAMERA"/>
```

Inside the `<application>` tag, the FCM default channel hint (the channel
itself is created at runtime by `FcmService`):

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="tailoring_orders_channel"/>
```

### `android/app/build.gradle.kts` (or `.gradle`)

Make sure `minSdk` is at least **23** (required by `firebase_auth` / `firebase_storage`):

```kotlin
defaultConfig {
    minSdk = 23
    targetSdk = 34
}
```

---

## 🍎 iOS

### `ios/Runner/Info.plist`

Add inside the top-level `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>So you can capture fabric and style reference photos for your orders.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>So you can attach fabric and style reference photos to your orders.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Not used by this app.</string>

<!-- FCM background fetch -->
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Push capability

In Xcode → `Runner` target → **Signing & Capabilities** →

- Add **Push Notifications**
- Add **Background Modes** → tick *Remote notifications*
- Upload your APNs **Auth Key** in Firebase Console → Project Settings → Cloud Messaging

### Minimum iOS

Open `ios/Podfile` and set:

```ruby
platform :ios, '13.0'
```

---

## 🔥 Firebase project

Enable these products from the Firebase Console:

1. **Authentication** → Sign-in method → **Email/Password** ✅
2. **Cloud Firestore** → start in production mode → deploy `firestore.rules` (see project root)
3. **Cloud Storage** → default bucket → deploy `storage.rules`
4. **Cloud Messaging** (no setup needed)
5. (Optional, for push delivery) **Cloud Functions** → deploy `functions/index.js` (Blaze plan required)

Deploy the rules from the project root:

```bash
firebase deploy --only firestore:rules,storage
```
