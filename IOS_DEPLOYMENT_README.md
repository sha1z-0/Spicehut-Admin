# iOS App Store Deployment Guide (SpiceHut Admin)

This is the complete end-to-end guide to ship the **SpiceHut Admin** Flutter app to the **Apple App Store**.

> Important: **You must use a Mac with Xcode** to create and sign App Store builds. You cannot do the full iOS App Store release process from Windows.

---

## 0) Requirements (cannot skip)

- A **Mac** with the latest **Xcode** installed
  - Options: your own Mac, a rented Mac (MacStadium), or CI (Codemagic/Bitrise) that provides macOS
- **Apple Developer Program** membership
- Access to **App Store Connect**
- A stable **production backend** URL (your app must point to production API)

---

## 1) Confirm the production API URL in the app

This project currently uses hardcoded production URLs in:

- [lib/services/api_service.dart](lib/services/api_service.dart)

Before you build a release, confirm these values are correct:

- `ApiService.baseUrl` must be `https://<your-backend-domain>/api`
- `ApiService.socketUrl` must be `https://<your-backend-domain>`

If you deploy the backend somewhere new, update those values **before** building iOS.

---

## 2) Increase version + build number

In [pubspec.yaml](pubspec.yaml), update the version:

```yaml
version: 1.0.3+12
```

Rules:

- `1.0.3` = the marketing version users see on the App Store
- `+12` = build number (must increase for every upload to App Store Connect)

---

## 3) Prepare the project on macOS

On the Mac terminal, from the Flutter project root:

```bash
flutter clean
flutter pub get
```

Then install CocoaPods:

```bash
cd ios
pod install
cd ..
```

Sanity check:

```bash
flutter doctor
```

Fix any Xcode/CocoaPods issues before continuing.

---

## 4) Open the correct Xcode project

Open the workspace (recommended for Flutter projects):

- [ios/Runner.xcworkspace](ios/Runner.xcworkspace)

Do not use `Runner.xcodeproj` for typical Flutter iOS release workflows.

### If `Runner.xcworkspace` opens blank

On macOS, a “blank” Xcode window is usually one of these:

1. You opened the wrong thing (open **`ios/Runner.xcworkspace`**, not `Runner.xcodeproj`).
2. The Project Navigator is hidden (press **Cmd+0** to toggle it).
3. CocoaPods workspace files weren’t generated yet:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

Then re-open `ios/Runner.xcworkspace`.

---

## 5) Configure signing and Bundle ID (most important step)

In Xcode:

1. Select **Runner** (project)
2. Select **Runner** (target)
3. Go to **Signing & Capabilities**
4. Set:
   - **Team**: your Apple Developer team
   - Enable **Automatically manage signing** (recommended)
   - **Bundle Identifier**: the final ID you will use in App Store Connect
     - Example: `com.sha1z.spicehutadmin`

Common failure modes here:

- Bundle ID mismatch between Xcode and App Store Connect
- Using a team/account that does not have the correct permissions

---

## 6) Verify Info.plist permissions (already present in this repo)

Apple can reject if you request permissions without clear reasons.

This project already contains common permission strings in:

- [ios/Runner/Info.plist](ios/Runner/Info.plist)

Quick check that the text matches what the app does (camera/photos/bluetooth/local network, etc.).

---

## 7) Build a release (Flutter)

On the Mac:

```bash
flutter build ios --release
```

Notes:

- This compiles a release build, but it does **not** upload to App Store Connect.
- The actual submission is done via **Xcode Archive/Organizer**.

---

## 8) Archive in Xcode (App Store build)

In Xcode:

1. Select a destination like **Any iOS Device (arm64)** / **Generic iOS Device**
2. Menu: **Product → Archive**
3. Organizer opens and shows the new archive

If **Archive** is disabled:

- You’re probably targeting a simulator; switch to a generic/physical iOS device target.

---

## 9) Upload to App Store Connect (creates TestFlight build)

In Organizer:

1. **Distribute App**
2. Choose **App Store Connect**
3. Choose **Upload**
4. Follow the prompts until upload completes

Then in App Store Connect, wait for build processing (often 10–60 minutes).

---

## 9A) Upload using Transporter (instead of Xcode Upload)

You can use **Transporter** to upload builds to App Store Connect, but note:

- Transporter only **uploads** an `.ipa`.
- You still need Xcode (GUI) or Xcode tools/CI to **create + sign** an App Store `.ipa`.

### Step 1: Create an App Store `.ipa`

Option A (Xcode Organizer export):

1. In Xcode Organizer, select your Archive
2. **Distribute App**
3. **App Store Connect**
4. Choose **Export** (not Upload) to generate an `.ipa`

Option B (CI / command line):

- Generate an `.xcarchive` and export an App Store `.ipa` using `xcodebuild -archive` / `xcodebuild -exportArchive`.

### Step 2: Upload with Transporter

1. Install **Transporter** from the Mac App Store
2. Open Transporter and sign in with your Apple ID (must have App Store Connect access)
3. Drag and drop the exported `.ipa` into Transporter
4. Click **Deliver**

If the upload succeeds, the build will appear in App Store Connect → **TestFlight** after processing.

---

## 10) App Store Connect setup (first time)

In App Store Connect:

1. **My Apps → + → New App**
2. Fill:
   - App name
   - Primary language
   - Bundle ID (must match Xcode)
   - SKU

Complete required sections:

- **App Privacy** (nutrition label)
- **Age Rating** (this project includes an age gate)
- **Privacy Policy URL** (Apple typically expects a URL even if you show it in-app)
- Screenshots (required sizes)
- Description, keywords, support URL

---

## 11) TestFlight (recommended before App Store release)

App Store Connect → your app → **TestFlight**:

1. Add internal testers
2. Install via TestFlight
3. Verify:
   - Login works against production backend
   - Orders load/refresh correctly
   - Printer + Bluetooth flow works
   - Age verification + privacy policy acceptance flow behaves correctly

Related compliance docs:

- [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [AGE_VERIFICATION_TESTING_GUIDE.md](AGE_VERIFICATION_TESTING_GUIDE.md)

---

## 12) Submit to App Review

App Store Connect → your app → your version:

1. Fill review info
2. Provide demo credentials if the app is login-gated (reviewers must be able to test)
3. Answer export compliance / encryption questions honestly
4. **Submit for Review**

---

## 13) Release

After approval:

- Release manually or schedule a release
- Monitor App Store Connect for any follow-up actions

---

## Common pitfalls (save time)

- Trying to do iOS App Store build from Windows (not possible)
- Trying to emulate macOS on Windows / Hackintosh for App Store builds (typically violates Apple licensing and is unreliable for signing)
- Bundle ID mismatch (Xcode vs App Store Connect)
- Build number not incremented
- Wrong production API URL hardcoded
- Permission strings not matching actual usage

---

## Optional: tailor this guide to your exact config

If you want this guide to be 100% plug-and-play for your team, note down:

- Final Bundle Identifier
- Your production backend domain
- Apple Team name

Then update this file with those exact values.
