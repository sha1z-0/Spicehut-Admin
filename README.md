# SpiceHut Admin (Flutter) + Backend (Node/Express)

Restaurant admin dashboard app (Flutter) + backend API (Node.js/Express + MongoDB) used to manage branches, menu, orders, analytics, in-house tables, and staff access.

This README is the “start here” guide when you clone the repo.

## Table of contents

- What’s in this repo
- Local development (backend + app)
- Configuration (API base URL)
- Production deployment (backend)
- Store releases (iOS App Store / Android Play Store)
- Compliance (age gate + privacy policy)
- Troubleshooting
- More docs

## What’s in this repo

**Top-level structure**

```
backend/              # Express API + MongoDB (deployed)
lib/                  # Flutter app source
android/ ios/ web/    # Flutter platforms
assets/               # Logos + sounds
test/                 # Flutter tests
```

**Main screens**

1. Sign In
2. Dashboard
3. Incoming Orders
4. Order History
5. Analytics
6. In-House Tables
7. On-Call Orders
8. Menu Management
9. User Management
10. Printer Setup (guide)

## Local development

### Prerequisites

- Flutter SDK installed
- Node.js installed (for backend)
- MongoDB Atlas connection string (recommended) or any MongoDB instance

### 1) Backend (Terminal 1)

Create your backend env file:

- Copy [backend/.env.example](backend/.env.example) to `backend/.env`
- Fill in `MONGO_URI` and `JWT_SECRET`

Then run:

```bash
cd backend
npm install
npm run dev
```

Backend default: `http://localhost:4000` and API under `/api`.

### 2) Flutter app (Terminal 2)

```bash
flutter pub get
flutter run
```

## Configuration (API base URL)

The app currently uses a hardcoded production URL in:

- [lib/services/api_service.dart](lib/services/api_service.dart)

Update `ApiService.baseUrl` to point to:

- Local backend: `http://localhost:4000/api`
- Android emulator: `http://10.0.2.2:4000/api`
- Physical device on LAN: `http://<your-lan-ip>:4000/api`
- Production: your Vercel/Render URL + `/api`

## Production backend deployment

Use the full step-by-step guide:

- [DEPLOYMENT_COMPLETE_GUIDE.md](DEPLOYMENT_COMPLETE_GUIDE.md)

Key reminders:

- Never commit `backend/.env` (this repo ignores it)
- Configure backend environment variables in your hosting provider

## Store releases

### Shared prerequisites (before any store upload)

1. Production backend is deployed and stable
2. App name + icons are final
3. Privacy policy is available (URL + in-app)
4. Update version/build number in `pubspec.yaml`

### Android (Google Play)

1) Bump version/build in `pubspec.yaml`, e.g.:

```yaml
version: 1.0.3+12
```

2) Build release bundle:

```bash
flutter build appbundle --release
```

Output:

```
build/app/outputs/bundle/release/app-release.aab
```

3) Upload to Play Console (Production or Internal testing) and complete:

- Store listing (screenshots, description)
- Data Safety
- Content rating
- Privacy policy link

### iOS (Apple App Store)

Important: iOS App Store builds require macOS + Xcode. You cannot produce an App Store archive from Windows alone.

1) Bump version/build in `pubspec.yaml` (must increase every upload)

2) On a Mac:

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
```

3) Open the workspace in Xcode:

```
ios/Runner.xcworkspace
```

4) In Xcode → Runner target → Signing & Capabilities:

- Set your Team
- Set your Bundle Identifier
- Enable “Automatically manage signing” (simplest)

5) Build/Archive and upload:

- Xcode: Product → Archive
- Organizer: Distribute App → App Store Connect → Upload

6) Use TestFlight first (recommended), then submit the release for review.

## Compliance (age verification + privacy policy)

This project includes an age gate and in-app privacy policy modal.

- [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [AGE_VERIFICATION_TESTING_GUIDE.md](AGE_VERIFICATION_TESTING_GUIDE.md)
- Privacy policy text: [lib/screens/privacy_policy_modal.dart](lib/screens/privacy_policy_modal.dart)

## Troubleshooting

- Login fails: confirm backend is reachable and JWT secret is set
- App loads but no data: confirm `ApiService.baseUrl` points to the correct API
- iOS build errors: run `pod install`, verify signing, update Xcode

## More docs

- Full documentation: [COMPLETE_DOCUMENTATION.md](COMPLETE_DOCUMENTATION.md)
- API reference: [API_REFERENCE.md](API_REFERENCE.md)
- In-house tables: [INHOUSE_TABLES_QUICKSTART.md](INHOUSE_TABLES_QUICKSTART.md)
- Backend deep-dive: [INHOUSE_TABLES_BACKEND_DOCUMENTATION.md](INHOUSE_TABLES_BACKEND_DOCUMENTATION.md)

---

Updated: February 2026
