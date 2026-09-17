# Complete Deployment Guide - SpiceHut Admin App
## Backend + Frontend Deployment for Absolute Beginners

---

## **PART 1: UNDERSTANDING YOUR BACKEND**

### What is the Backend?
Your backend is a **Node.js server** that:
- Handles all database operations (MongoDB)
- Manages user authentication (JWT tokens)
- Processes orders in real-time (Socket.IO)
- Serves API endpoints for your mobile app

### Backend Files (What Gets Deployed)

**📁 Your backend folder contains:**
```
backend/
├── server.js               ✅ MAIN FILE (4000+ lines - the entire backend)
├── package.json            ✅ REQUIRED (lists dependencies)
├── models/
│   └── AdminUser.ts        ✅ REQUIRED (database schema)
├── .env                    ❌ LOCAL ONLY (secrets - never upload!)
├── .env.example            ✅ TEMPLATE (shows what .env needs)
├── vercel.json             ✅ REQUIRED FOR VERCEL
├── .vercelignore           ✅ REQUIRED FOR VERCEL
├── node_modules/           ❌ AUTO-GENERATED (never upload)
└── test files              ❌ NOT NEEDED for production
```

**What gets deployed to Vercel/Render:**
- ✅ `server.js` - Your entire backend code
- ✅ `package.json` - Tells server what packages to install
- ✅ `models/AdminUser.ts` - Database structure
- ✅ `vercel.json` - Vercel configuration
- ✅ `.vercelignore` - What Vercel should ignore

---

## **PART 2: CHOOSING YOUR HOSTING**

### **VERCEL vs RENDER COMPARISON**

| Feature | Vercel (Recommended) | Render |
|---------|---------------------|---------|
| **Ease of Setup** | ⭐⭐⭐⭐⭐ Easiest | ⭐⭐⭐⭐ Easy |
| **Free Tier** | 100GB bandwidth/month | 750 hours/month |
| **Speed** | Very Fast (Edge network) | Fast (Single region) |
| **Socket.IO Support** | ✅ Yes (with config) | ✅ Yes (better) |
| **Auto Deploy** | ✅ GitHub integration | ✅ GitHub integration |
| **Custom Domain** | ✅ Free SSL | ✅ Free SSL |
| **MongoDB Compatible** | ✅ Yes | ✅ Yes |
| **Startup Time** | ✅ Instant | ⚠️ Can sleep (free tier) |
| **Best For** | Quick deployment, global apps | Always-on services |

**MY RECOMMENDATION: Start with VERCEL** (easier, faster, better for beginners)

---

## **PART 3: DEPLOY BACKEND STEP-BY-STEP**

### **STEP 1: Get MongoDB Atlas (Free Database)**

**Why?** Your backend needs a database to store orders, users, menu items.

**How to set it up:**

1. **Go to:** https://www.mongodb.com/cloud/atlas/register
2. **Sign up** with Google/Email (100% free forever)
3. **Create a cluster:**
   - Choose **FREE tier (M0)**
   - Select region closest to you (e.g., AWS US-East if you're in North America)
   - Cluster name: `spicehut-production`
   - Click **Create**

4. **Create database user:**
   - Go to **Database Access** (left sidebar)
   - Click **Add New Database User**
   - Authentication: **Password**
   - Username: `spicehut_admin`
   - Password: Click **Autogenerate Secure Password** → **Copy it somewhere safe!**
   - Database User Privileges: **Read and write to any database**
   - Click **Add User**

5. **Allow connections:**
   - Go to **Network Access** (left sidebar)
   - Click **Add IP Address**
   - Click **Allow Access from Anywhere** (⚠️ This is safe because you have password)
   - Click **Confirm**

6. **Get connection string:**
   - Go to **Database** (left sidebar)
   - Click **Connect** on your cluster
   - Choose **Connect your application**
   - Driver: **Node.js**, Version: **4.1 or later**
   - Copy the connection string (looks like this):
   ```
   mongodb+srv://spicehut_admin:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
   ```
   - **IMPORTANT:** Replace `<password>` with your actual password from step 4
   - **Save this!** You'll need it in a minute.

---

### **STEP 2: Deploy to Vercel**

**Why Vercel?** Free, fast, automatic deployments from GitHub.

**Prerequisites:**
- GitHub account (create at github.com if you don't have one)
- Your code pushed to GitHub repository

#### **2A: Push Code to GitHub (if not already done)**

```bash
# Open terminal in your project root (not backend folder)
cd "d:\Hamzaappp\Flutter App Admin Side"

# Initialize git if not already
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit - SpiceHut Admin App"

# Create repository on GitHub:
# 1. Go to github.com
# 2. Click "+" → "New repository"
# 3. Name: "spicehut-admin-app"
# 4. Keep it Private
# 5. Don't initialize with README
# 6. Click "Create repository"

# Link your local code to GitHub (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/spicehut-admin-app.git

# Push to GitHub
git branch -M main
git push -u origin main
```

#### **2B: Deploy Backend on Vercel**

1. **Go to:** https://vercel.com/signup
2. **Sign up** with GitHub (easiest)
3. **Import Project:**
   - Click **Add New...** → **Project**
   - Select your GitHub repository: `spicehut-admin-app`
   - Click **Import**

4. **Configure Project:**
   - **Framework Preset:** Other
   - **Root Directory:** Click **Edit** → Enter `backend` → Save
   - **Build Command:** Leave empty (or `npm install`)
   - **Output Directory:** Leave empty
   - **Install Command:** `npm install`

5. **Add Environment Variables:**
   Click **Environment Variables** section and add these 3 variables:

   **Variable 1:**
   - Name: `MONGODB_URI`
   - Value: Paste your MongoDB connection string from Step 1 (with password filled in)
   
   **Variable 2:**
   - Name: `JWT_SECRET`
   - Value: Generate a random 32+ character string (use this generator or type random keys):
   ```
   Example: f8k3n2d9s7a4j6h8g5d3s1a9z7x4c6v2b8n5m3
   ```
   
   **Variable 3:**
   - Name: `NODE_ENV`
   - Value: `production`

6. **Deploy:**
   - Click **Deploy** button
   - Wait 2-3 minutes ⏳
   - You'll see **"Congratulations!"** when done

7. **Get Your Backend URL:**
   - After deployment, you'll see a URL like:
   ```
   https://spicehut-admin-app-backend.vercel.app
   ```
   - **Your API Base URL** is this URL + `/api`:
   ```
   https://spicehut-admin-app-backend.vercel.app/api
   ```
   - **Copy this!** You need it for the mobile app.

8. **Test Your Backend:**
   - Open browser, go to: `https://your-vercel-url.vercel.app/api/health`
   - You should see:
   ```json
   {
     "status": "healthy",
     "uptime": 123.456,
     "timestamp": "2026-02-07T..."
   }
   ```
   - If you see this, **backend is live!** ✅

---

### **ALTERNATIVE: Deploy to Render (If Vercel has issues)**

1. **Go to:** https://render.com/
2. **Sign up** with GitHub
3. **Create Web Service:**
   - Click **New +** → **Web Service**
   - Connect your GitHub repository
   - Select `spicehut-admin-app` repository

4. **Configure:**
   - Name: `spicehut-backend`
   - Region: Choose closest to you
   - Branch: `main`
   - Root Directory: `backend`
   - Runtime: `Node`
   - Build Command: `npm install`
   - Start Command: `node server.js`
   - Instance Type: **Free**

5. **Add Environment Variables:**
   - Scroll down to **Environment Variables**
   - Add the same 3 variables from Vercel step
   - `MONGODB_URI`, `JWT_SECRET`, `NODE_ENV`

6. **Create Web Service:**
   - Click **Create Web Service**
   - Wait 5-10 minutes for first deployment
   - Your URL will be: `https://spicehut-backend.onrender.com`
   - API Base: `https://spicehut-backend.onrender.com/api`

**⚠️ Render Free Tier Note:** 
- Service sleeps after 15 minutes of inactivity
- First request after sleep takes 30-60 seconds to wake up
- Good for testing, but consider paid tier ($7/mo) for production

---

## **PART 4: SEED YOUR DATABASE**

Before using the app, you need admin accounts in the database.

### **Method 1: Using the Test Endpoint (Easiest)**

1. Your backend has a seeding endpoint at `/api/test/seed-admins`
2. Open Postman, Insomnia, or your browser
3. Make a GET request to:
   ```
   https://your-vercel-url.vercel.app/api/test/seed-admins
   ```
4. You'll get response:
   ```json
   {
     "success": true,
     "message": "Admin users created",
     "users": [...]
   }
   ```

5. **Test Accounts Created:**
   - **Super Admin:** `admin@spicehut.com` / password: `admin123`
   - **Comox Manager:** `manager.comox@spicehut.com` / password: `manager123`
   - **Courtenay Manager:** `manager.courtenay@spicehut.com` / password: `manager123`

**⚠️ SECURITY:** After testing, this endpoint is disabled in production (NODE_ENV=production). That's why we included the check in server.js.

### **Method 2: Using MongoDB Compass (More Control)**

1. **Download MongoDB Compass:** https://www.mongodb.com/try/download/compass
2. **Connect:**
   - Open Compass
   - Paste your MongoDB connection string
   - Click **Connect**

3. **Create Admin:**
   - Navigate to database: `restaurant_management`
   - Collection: `adminusers`
   - Click **Add Data** → **Insert Document**
   - Paste this (change email/password):
   ```json
   {
     "email": "youremail@example.com",
     "password": "$2a$10$abcdefghijklmnopqrstuv",
     "name": "Your Name",
     "role": "admin",
     "isActive": true,
     "createdAt": { "$date": "2026-02-07T00:00:00.000Z" }
   }
   ```
   - For password, use bcrypt online generator: https://bcrypt-generator.com
   - Rounds: 10
   - Generate hash for your desired password

---

## **PART 5: DEPLOY FRONTEND (MOBILE APP)**

### **What Needs to Change in Your Code**

**Only 1 thing changes:** The API URL

**Current (Development):**
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://localhost:4000/api';
static const String socketUrl = 'http://localhost:4000';
```

**After Deployment (Production):**
```dart
// Will be provided at BUILD TIME (not in code)
// Build command passes the real URL
```

### **You DON'T Change Code. You Change BUILD COMMAND!**

**Wrong Way ❌:**
```dart
// Don't hardcode production URL in code!
static const String baseUrl = 'https://my-backend.vercel.app/api';
```

**Right Way ✅:**
```bash
# Pass URL during build
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.vercel.app/api
```

Why? Because:
- You can build for **different environments** (staging, production)
- No need to change code between builds
- More secure (URL not visible in repository)

---

### **Build Android APK (for Play Store)**

**Step 1: Update App Metadata**

Edit `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        applicationId "com.spicehut.admin"  // Change from default
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1              // Increase on each upload
        versionName "1.0.0"        // User-facing version
    }
}
```

**Step 2: Build Release APK**

```bash
cd "d:\Hamzaappp\Flutter App Admin Side"

# Build APK (for testing on device)
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app

# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Step 3: Build App Bundle (for Play Store)**

```bash
# App Bundle (smaller, optimized for Play Store)
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app

# Output: build/app/outputs/bundle/release/app-release.aab
```

### **Upload to Google Play Store**

**Prerequisites:**
- Google Play Developer account ($25 one-time fee)
- Signed app bundle (generated above)

**Steps:**

1. **Go to:** https://play.google.com/console
2. **Create App:**
   - Click **Create app**
   - App name: **SpiceHut Admin**
   - Default language: English (US)
   - App or game: **App**
   - Free or paid: **Free**
   - Accept declarations
   - Click **Create app**

3. **Complete Store Listing:**
   - **App details:**
     - Short description (80 chars): "Restaurant management app for SpiceHut staff"
     - Full description: Copy from your app's purpose
   - **Graphics:**
     - Icon: 512×512 PNG (use your spicehut_logo.png, resize it)
     - Feature graphic: 1024×500 PNG (create a banner)
     - Screenshots: Take 2-8 screenshots from app (phone + tablet)

4. **Content Rating:**
   - Click **Start questionnaire**
   - Category: **Utility, Productivity, or Business**
   - Answer questions (all "No" for restaurant admin app)
   - Get rating (should be "Everyone" or "Everyone 10+")

5. **Privacy Policy:**
   - Your privacy policy is already in the app
   - For Play Store, you can host it on GitHub:
     - Create file `PRIVACY_POLICY.md` in your repo
     - Get raw URL: `https://raw.githubusercontent.com/YOUR_USERNAME/spicehut-admin-app/main/PRIVACY_POLICY.md`
     - Or paste directly in Play Console

6. **Upload App Bundle:**
   - Go to **Production** → **Create new release**
   - Upload your `app-release.aab` file
   - Release name: `1.0.0` (matches versionName)
   - Release notes: "Initial release"
   - Click **Save**

7. **Submit for Review:**
   - Complete all required sections (green checkmarks)
   - Click **Submit for review**
   - Wait 1-3 days for approval

---

### **Build iOS App (for App Store)**

**Step 1: Setup Xcode**

```bash
# Open iOS project
cd "d:\Hamzaappp\Flutter App Admin Side"
open ios/Runner.xcworkspace
```

**IN XCODE:**

1. **Select Runner** (top of left sidebar)
2. **General tab:**
   - Display Name: `SpiceHut Admin`
   - Bundle Identifier: `com.spicehut.admin` (must be unique)
   - Version: `1.0.0`
   - Build: `1`

3. **Signing & Capabilities:**
   - Team: Select your Apple Developer team
   - Bundle Identifier: Same as above
   - Automatically manage signing: ✅ Checked

**Step 2: Build for App Store**

```bash
# Build iOS (requires macOS)
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app
```

**Step 3: Archive in Xcode**

1. In Xcode: **Product** → **Scheme** → Select **Runner**
2. **Product** → **Destination** → **Any iOS Device**
3. **Product** → **Archive**
4. Wait for archive to complete (5-10 minutes)
5. Archive Organizer opens automatically

**Step 4: Upload to App Store**

1. In Archive Organizer, click **Distribute App**
2. Choose: **App Store Connect**
3. Click **Upload**
4. Wait for validation (2-5 minutes)
5. Click **Upload**

**Step 5: Submit on App Store Connect**

1. **Go to:** https://appstoreconnect.apple.com
2. **Create App:**
   - Click **Apps** → **+** icon
   - Name: **SpiceHut Admin**
   - Primary Language: English (US)
   - Bundle ID: Select `com.spicehut.admin`
   - SKU: `spicehut-admin-001`
   - Click **Create**

3. **App Information:**
   - Privacy Policy URL: (host your policy or use GitHub raw URL)
   - Category: Business or Utilities
   - Age Rating: 4+ or 9+ (answer questionnaire honestly)

4. **Pricing:**
   - Price: **Free**
   - Availability: Select countries

5. **Version Information:**
   - Screenshots: 6.5" iPhone required (use simulator)
   - Promotional text: Short tagline
   - Description: Full app description
   - Keywords: restaurant, management, admin, orders, POS
   - Support URL: Your website or GitHub
   - Marketing URL: (optional)

6. **Build:**
   - Click **+** next to Build
   - Select the build you uploaded from Xcode
   - Click **Done**

7. **Submit for Review:**
   - Click **Submit for Review**
   - Wait 1-5 days for approval

---

## **PART 6: TESTING BEFORE SUBMISSION**

### **Test Backend is Working**

**Open browser or Postman:**

1. **Health Check:**
   ```
   GET https://your-backend.vercel.app/api/health
   ```
   Expected: `{"status": "healthy", ...}`

2. **Login Test:**
   ```
   POST https://your-backend.vercel.app/api/auth/login
   Body: {
     "email": "admin@spicehut.com",
     "password": "admin123"
   }
   ```
   Expected: `{"success": true, "token": "eyJhbG...", ...}`

3. **Dashboard Test:**
   ```
   GET https://your-backend.vercel.app/api/dashboard/stats?branch=comox
   Headers: Authorization: Bearer YOUR_TOKEN_FROM_STEP_2
   ```
   Expected: `{"success": true, "data": {...}}`

### **Test Mobile App Before Upload**

**Install APK on Android Device:**
```bash
# Connect Android phone via USB
# Enable USB Debugging on phone: Settings → About → Tap Build Number 7 times

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Or send APK to phone via email/drive and install manually
```

**Test iOS on Physical Device:**
```bash
# Connect iPhone via USB
# Trust computer on iPhone

flutter run --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app
```

**What to Test:**
- ✅ Age verification works
- ✅ Privacy policy requires scroll and accept
- ✅ Login works with test credentials
- ✅ Dashboard loads data (after selecting branch)
- ✅ Orders display in real-time
- ✅ Order status updates work
- ✅ App doesn't crash on any screen
- ✅ Icons display correctly
- ✅ Permissions work (camera, notifications)

---

## **PART 7: ENVIRONMENT VARIABLES CHEAT SHEET**

### **Backend Environment Variables (Vercel/Render)**

```bash
# REQUIRED (App won't work without these)
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/restaurant_management
JWT_SECRET=your-random-32-character-secret-key-here
NODE_ENV=production

# OPTIONAL (if you add features later)
PORT=4000  # Render uses this, Vercel ignores it
ALLOWED_ORIGINS=*  # CORS (already set in code)
```

### **Frontend Build Commands**

```bash
# Development (local backend)
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api

# Android Emulator (local backend)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api

# Production Build (Vercel backend)
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app

# iOS Production Build
flutter build ios --release \
  --dart-define=API_BASE_URL=https://your-backend.vercel.app/api \
  --dart-define=SOCKET_URL=https://your-backend.vercel.app
```

---

## **PART 8: TROUBLESHOOTING**

### **Backend Issues**

**Problem: "Application error" on Vercel**
- Check Vercel deployment logs (click on deployment → View Function Logs)
- Common causes:
  - Missing environment variables
  - Wrong MONGODB_URI format
  - JWT_SECRET too short (<32 chars)

**Problem: "Connection refused" from app**
- Make sure URL in build command has `/api` at the end
- Check Vercel function is running: visit `/api/health` in browser
- Verify MongoDB IP whitelist allows all IPs (0.0.0.0/0)

**Problem: Socket.IO not working**
- Vercel: Make sure `vercel.json` has WebSocket config (already included)
- Render: Should work out of the box
- Test socket connection in browser console:
  ```javascript
  const socket = io('https://your-backend.vercel.app');
  socket.on('connect', () => console.log('Connected!'));
  ```

### **Frontend Issues**

**Problem: "Failed to load: 400" errors**
- You're logged in as admin but haven't selected a branch
- Solution: Add branch dropdown selection in dashboard (already coded)
- Or: Create a manager account instead of admin

**Problem: App crashes on launch**
- Check `flutter logs` for error details
- Common causes:
  - Missing assets (logo file)
  - Incorrect API URL in build command
  - Network permissions not set

**Problem: iOS build fails**
- Make sure you have valid Apple Developer account
- Check Bundle ID is unique and matches provisioning profile
- Run `flutter clean` then try again
- Check Xcode signing settings

**Problem: Age verification overflows**
- Already fixed in latest code (SafeArea + SingleChildScrollView)
- If still happening, test on physical device (emulator might have odd dimensions)

---

## **PART 9: MAINTENANCE & UPDATES**

### **Updating Backend (After Initial Deploy)**

**Vercel (Automatic):**
1. Make changes to `backend/server.js`
2. Commit and push to GitHub:
   ```bash
   git add .
   git commit -m "Update backend logic"
   git push
   ```
3. Vercel auto-deploys in 1-2 minutes ✅

**Render (Automatic):**
- Same as Vercel - push to GitHub triggers auto-deploy

### **Updating Mobile App**

1. **Make code changes**
2. **Increment version:**
   - Android: `android/app/build.gradle` → `versionCode++`, update `versionName`
   - iOS: Xcode → General → Version & Build number
3. **Build new release:**
   ```bash
   flutter build appbundle --release --dart-define=API_BASE_URL=...
   ```
4. **Upload to stores:**
   - Play Store: Production → Create new release → Upload AAB
   - App Store: Archive → Upload → Submit update

### **Monitoring Your Backend**

**Vercel:**
- Dashboard shows request count, errors, response times
- View logs: Project → Deployments → Click deployment → Logs

**MongoDB:**
- Atlas dashboard shows storage usage, operation counts
- Set up alerts for connection issues

**App Analytics:**
- Consider adding Firebase Analytics to mobile app
- Track crashes with Firebase Crashlytics
- Monitor user engagement

---

## **SUMMARY: YOUR DEPLOYMENT CHECKLIST**

### **Backend ✅**
- [ ] MongoDB Atlas cluster created
- [ ] Database user created with password
- [ ] Connection string copied
- [ ] Code pushed to GitHub
- [ ] Vercel/Render account created
- [ ] Project deployed with environment variables
- [ ] Health endpoint tested (`/api/health`)
- [ ] Admin users seeded
- [ ] Login tested via Postman

### **Frontend ✅**
- [ ] Backend URL from step above noted
- [ ] Age verification + privacy policy tested locally
- [ ] App icons generated (`flutter pub run flutter_launcher_icons`)
- [ ] Android APK/AAB built with production URL
- [ ] iOS IPA built and archived (if deploying to iOS)
- [ ] App tested on physical device
- [ ] All features working (login, orders, real-time updates)

### **App Stores ✅**
- [ ] Google Play Developer account ($25) - for Android
- [ ] Apple Developer account ($99/year) - for iOS
- [ ] Store listing completed (description, screenshots, icon)
- [ ] Content rating questionnaire completed
- [ ] Privacy policy URL provided
- [ ] App bundle uploaded
- [ ] Submitted for review

---

## **ESTIMATED COSTS**

| Item | Cost | Frequency |
|------|------|-----------|
| MongoDB Atlas (Free tier) | **$0** | Forever |
| Vercel (Free tier) | **$0** | Forever* |
| Render (Free tier) | **$0** | Forever* |
| Google Play Developer | **$25** | One-time |
| Apple Developer | **$99** | Per year |
| Domain (optional) | $10-15 | Per year |

*Free tiers have limits but sufficient for small-medium restaurants

**Total to start: $25 (Android) or $124 (iOS+Android)**

---

## **EXPECTED TIMELINE**

| Task | Time Required |
|------|---------------|
| MongoDB setup | 10 minutes |
| Vercel deployment | 15 minutes |
| Seed database | 5 minutes |
| Build Android APK | 10 minutes |
| Build iOS IPA | 20 minutes |
| Play Store listing | 1-2 hours |
| App Store listing | 1-2 hours |
| Play Store review | 1-3 days |
| App Store review | 1-5 days |

**Total: ~4 hours of work + 1-5 days review wait**

---

## **NEED HELP?**

**If you get stuck:**
1. Check Vercel/Render logs (99% of issues show there)
2. Test each endpoint individually in Postman
3. Check MongoDB Atlas connection (green dot = connected)
4. Verify environment variables are set correctly
5. Read error messages carefully (they usually tell you what's wrong)

**Common "I'm stuck" moments:**
- "Vercel says 'Application error'" → Check logs, verify JWT_SECRET is set
- "App says 'Failed to load: 400'" → Select branch in dropdown (admin users)
- "MongoDB connection timeout" → Check IP whitelist allows 0.0.0.0/0
- "iOS signing error" → Make sure Bundle ID matches provisioning profile

---

**You're ready to deploy! 🚀**

Start with MongoDB → Vercel → Test → Build APK → Deploy!
