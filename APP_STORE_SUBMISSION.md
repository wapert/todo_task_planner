# App Store 上架準備 — 待辦計畫 (Todo Task Planner)

Project facts this checklist is built on:

| | |
|---|---|
| Bundle ID (iOS) | `com.wapertech.todoTaskPlanner` |
| Bundle ID (Android) | `com.todo.taskplanner.todo_task_planner` (unchanged) |
| iOS min version | 15.0 (raised from 13.0 — Firebase SPM requires it) |
| Display name | `Todo Task Planner` (Info.plist) — app UI is Traditional Chinese |
| Version | `1.0.0+1` (pubspec.yaml) |
| Device family | iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Firebase project | `todo-planner-167b3` |
| Sign-in | Google + email/password (Firebase Auth) |
| Backend data | Cloud Firestore (`users/{uid}/tasks`) |

---

## A. Blockers — must be fixed before submitting

These will get the build rejected (or fail to work at all). Ordered by severity.

### A1. Sign in with Apple — ⚠️ code done, console steps remain
Required because the app offers Google sign-in (Guideline 4.8).

**Implemented:** `sign_in_with_apple` + `crypto` added, `signInWithApple()` in
`AuthService` (SHA-256 nonce: hashed value to Apple, raw value to Firebase, so
a replayed token can't be accepted), an 使用 Apple 帳號登入 button that appears
only where Apple sign-in actually exists (iOS/macOS — hidden on Android), and
`ios/Runner/Runner.entitlements` declaring `com.apple.developer.applesignin`.

Account deletion also handles Apple accounts and **revokes the Apple token**
via `revokeTokenWithAuthorizationCode` — Apple requires that deleting an
account also removes the app from the user's Apple ID.

**Still to do (needs your accounts):**
1. **Apple Developer portal** → Identifiers → `com.todo.taskplanner.todoTaskPlanner`
   → enable the **Sign in with Apple** capability.
2. **Xcode** → Runner target → Signing & Capabilities → **+ Capability** →
   Sign in with Apple. This wires `Runner.entitlements` into the build
   (`CODE_SIGN_ENTITLEMENTS`), which hand-editing `project.pbxproj` should not
   be used for.
3. **Firebase Console** → Authentication → Sign-in method → **Apple** → Enable.

### A2. In-app account deletion — ✅ done
設定 → 帳號 → **刪除帳號**. Confirmation dialog → re-authentication (Google
picker for Google accounts, password prompt for email accounts) → wipes
`users/{uid}` and its `tasks` subcollection → deletes the Firebase Auth
account → returns to the login screen.

Cloud data is deleted **before** the auth account, since the Firestore rules
key off `request.auth.uid`; the reverse order would strand the data with no way
to reach it. Saved biometric credentials are cleared too.

### A3. Google sign-in on iOS — ✅ done
Enabling the Google provider had in fact created the iOS OAuth client too. I
re-downloaded `GoogleService-Info.plist` (now carrying `CLIENT_ID` and
`REVERSED_CLIENT_ID`) and registered the reversed client ID as a
`CFBundleURLTypes` URL scheme in `Info.plist`, which is what the OAuth callback
needs to return to the app.

### A4. Unused calendar permission — ✅ done
Removed `device_calendar` + `timezone` + `shared_preferences`, deleted
`system_calendar_service*.dart`, `calendar_account.dart`,
`calendar_connection_store.dart` and the orphaned `apple_mail_service.dart`,
stripped the native-calendar code out of `TaskProvider`, dropped both
`NSCalendars*UsageDescription` keys from `Info.plist`, and removed
`READ_CALENDAR`/`WRITE_CALENDAR` from AndroidManifest.

Verified against the built APK — only `USE_BIOMETRIC`, `INTERNET`,
`ACCESS_NETWORK_STATE`, `USE_FINGERPRINT` and the Play-services permission
remain.

Side effect: `device_calendar` was the last plugin without Swift Package
Manager support, so **all iOS plugins are now Swift Packages** and CocoaPods
can be removed from `ios/` if you want a faster build (`pod deintegrate`,
delete the Podfile, drop the two xcconfig includes). It also cleared the
Kotlin Gradle Plugin deprecation warning on Android.

### A5. Encryption compliance — ✅ done
`ITSAppUsesNonExemptEncryption = false` added to `Info.plist`, so uploads no
longer prompt the export-compliance question. Accurate here: the app uses only
HTTPS and platform-standard crypto.

---

## B. Prerequisites

1. **Apple Developer Program** membership (US$99/year) — enrolled and active.
2. **Xcode** installed and signed in with that Apple ID.
3. App Store Connect access for the same account.

---

## C. Materials to prepare

### C1. App icon — ✅ done
1024×1024 marketing icon plus all 15 device sizes are generated in
`ios/Runner/Assets.xcassets/AppIcon.appiconset/`, rendered from the same
`Icons.task_alt` glyph the login screen uses, in `#FF9500` on white.
**No alpha channel** (verified — alpha is an automatic rejection).

### C2. Screenshots — required
Upload for **both** iPhone and iPad, since the app targets both.

| Device | Pixels | Count |
|---|---|---|
| iPhone 6.9" (16 Pro Max) | 1320 × 2868 | 3–10 (min 1) |
| iPhone 6.5" (11 Pro Max) | 1242 × 2688 | optional fallback |
| iPad 13" | 2064 × 2752 | 3–10 (min 1) |

App Store Connect shows the authoritative list at upload time — check there if
Apple has changed sizes.

Suggested shots: 今日, 週計畫, 行事曆, 進度 (with the 本週/本月/自訂 selector),
設定. Capture with a few sample tasks in place — never with an empty state, and
never containing real personal data.

**Capturing from the Simulator** (gives exactly the pixel sizes Apple wants, so
no scaling or letterboxing is needed):

```bash
xcrun simctl list devices available
```

Boot the two devices that match the required sizes. Available on this Mac:
**iPhone 17 Pro Max** (6.9", 1320×2868) and **iPad Pro 13-inch (M5)**
(2064×2752) — both correct for Apple's current requirements. Then:

```bash
flutter run -d "iPhone 17 Pro Max" --release
```

Capture each screen with:

```bash
xcrun simctl io booted screenshot ~/Desktop/shot-today.png
```

Screenshots come out at native resolution, ready to upload as-is.

> Note: the app is behind a login, so a fresh Simulator starts at the sign-in
> screen. Someone has to sign in once (and add 3–4 sample tasks) before the
> interesting screens can be captured — that step needs your credentials, so it
> can't be automated on your behalf. Once signed in, the capture itself can be
> scripted.

### C3. Store listing text
Draft these (zh-Hant primary; add en-US if you want wider reach):

- **App name** (≤30 chars) — e.g. `待辦計畫`
- **Subtitle** (≤30 chars) — e.g. `每日任務與週計畫管理`
- **Promotional text** (≤170 chars, editable without a new build)
- **Description** (≤4000 chars) — features: 今日待辦、週計畫、行事曆、進度統計、
  跨裝置同步、生物辨識登入
- **Keywords** (≤100 chars, comma-separated, no spaces)
- **Category** — Productivity (primary)
- **Age rating** — questionnaire; expect 4+
- **Copyright** — e.g. `2026 Wapertech`

### C4. URLs — both required
- **Support URL** — required. A simple page with a contact email is enough.
- **Privacy policy URL** — **required**, because the app collects data and
  supports accounts. Must disclose: email address, task content, Firebase user
  ID, and Google Calendar access.
- Marketing URL — optional.

### C5. Privacy nutrition labels
Declare in App Store Connect (App Privacy). For this app:

| Data type | Collected | Linked to user | Purpose |
|---|---|---|---|
| Email address | Yes (Firebase Auth) | Yes | App functionality |
| User content — tasks | Yes (Firestore) | Yes | App functionality |
| User ID (Firebase UID) | Yes | Yes | App functionality |

No tracking, no ads, no data sold. Answer **"No"** to the tracking question.

### C6. App Review demo account — required
The app is behind a login, so review **will** be blocked without credentials.
Provide in App Review Information:
- A working **email/password** test account (not your personal one) —
  email/password is far easier for a reviewer than Google sign-in.
- Notes explaining the app is in Traditional Chinese and that biometric login
  is optional.

---

## D0. Build state — where things stand

The **release archive builds clean**:

```
✓ Built build/ios/archive/Runner.xcarchive (221.2MB)
[✓] App Settings Validation
    • Version Number: 1.0.0   • Build Number: 1
    • Display Name: Todo Task Planner
    • Deployment Target: 15.0
    • Bundle Identifier: com.wapertech.todoTaskPlanner
```

**A signed `.ipa` could not be produced here.** This Mac has only an *Apple
Development* certificate (`wapertech@yahoo.com.tw`) and no provisioning
profiles. App Store distribution requires an **Apple Distribution**
certificate, which is created by signing into the Apple Developer account —
it needs your credentials, so it can't be automated. The archive above is the
input to that step; Xcode signs and exports the `.ipa` from it (§D step 6).

> Note the account split: the Apple Developer identity on this Mac is
> **wapertech@yahoo.com.tw**, while Firebase/Google is **wapertech@gmail.com**.
> Make sure you sign in to Xcode with the Apple ID that owns the App Store
> Connect app record.

Fixed along the way:
- `IPHONEOS_DEPLOYMENT_TARGET` 13.0 → **15.0**. Firebase's Swift packages
  require 15.0 and the build failed outright before this. Consequence: iPhone
  6s / 7 / original SE can no longer install the app.
- Launch image was still Flutter's 1×1 placeholder; replaced with the app mark
  at 120/240/360 px.

## D. Submission steps

### Step 1 — Apple Developer Program
Enrol at developer.apple.com (US$99/year) if not already active. Everything
below is blocked until this exists.

### Step 2 — App ID
developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** →
confirm `com.wapertech.todoTaskPlanner` exists, and that **Sign in with Apple**
is enabled on it. *(You reported this done.)*

### Step 3 — Sign in to Xcode
Xcode → Settings → Accounts → **+** → Apple ID → sign in with the account that
owns the App ID. This is what creates the **Apple Distribution** certificate
that's currently missing.

### Step 4 — Select the team
```bash
open ios/Runner.xcworkspace
```
Runner target → **Signing & Capabilities**:
- Tick **Automatically manage signing**
- Choose your **Team**
- Confirm **Sign in with Apple** appears in the capability list (the
  entitlements file is already wired, so it should)

### Step 5 — App Store Connect record — ✅ done

### Step 6 — Build and sign the IPA — ✅ done
`build/ios/ipa/todo_task_planner.ipa`, signed with an Apple Distribution
certificate, verified with `codesign --verify --deep --strict`.

Every upload needs a unique, increasing build number — bump `version: 1.0.0+1`
in `pubspec.yaml` to `+2`, `+3`, … before building again.

### Step 7 — Upload — ✅ done
Delivered via Transporter. First attempt failed with *"No suitable
application records were found"* — the App Store Connect record didn't exist
yet (Step 5 hadn't been done). Creating the record and re-delivering the same
IPA succeeded; no rebuild was needed.

### Step 8 — Wait for processing
10–60 minutes. The build then becomes selectable on the version page in
App Store Connect (My Apps → 待辦計畫 → the version → Build).

### Step 9 — TestFlight (do not skip)
Install on a real iPhone and verify, at minimum:
- Sign in with Apple *(never tested)*
- Google sign-in on iOS *(never tested)*
- **刪除帳號** end-to-end on a throwaway account *(never tested — reviewers
  check this directly)*
- Firestore sync and Google Calendar sync

### Step 10 — Complete the listing
Screenshots, description, keywords, subtitle, support + privacy-policy URLs,
privacy nutrition labels, age rating, and the App Review demo account (§C).

### Step 11 — Submit for Review
Typically 24–48 hours for a first review.

---

## E. Pre-submission sanity checks

- [ ] Sign in with Apple — A1 code done; App ID capability + Xcode capability +
      Firebase provider still to enable, then test on a real device
- [x] Account deletion implemented — A2 (still needs an end-to-end test on a
      throwaway account)
- [x] Google sign-in configured for iOS — A3 (test on a real device)
- [x] No unused permissions declared — A4
- [x] `ITSAppUsesNonExemptEncryption` set — A5
- [ ] Icon has no alpha channel ✅
- [ ] Firestore security rules deployed and restrict access to the owner
- [ ] `flutter analyze` clean
- [ ] App tested on a physical iPhone, not just the Simulator
- [ ] Demo account works from a clean install
