# 🎨 App Icon Setup Guide - SpiceHut Admin

This guide explains how to apply the SpiceHut logo as the app icon for both iOS and Android.

## ✅ What's Already Done

- ✅ `spicehut_logo.png` saved at `assets/logo/spicehut_logo.png`
- ✅ `flutter_launcher_icons` package added to pubspec.yaml
- ✅ Icon configuration added to pubspec.yaml

## 🚀 Generate App Icons

The `flutter_launcher_icons` package automatically generates all required icon sizes from a single source image.

### Option 1: Using flutter_launcher_icons (Recommended)

#### Step 1: Install Dependencies
```bash
cd "Flutter App Admin Side"
flutter pub get
```

#### Step 2: Generate Icons
```bash
# For iOS and Android
flutter pub run flutter_launcher_icons

# For specific platform
flutter pub run flutter_launcher_icons:main ios      # iOS only
flutter pub run flutter_launcher_icons:main android  # Android only
```

#### Step 3: Verify
- **Android:** Check `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS:** Check `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

#### Step 4: Build
```bash
# Test with debug build
flutter run

# Or build for release
flutter build ios --release
flutter build appbundle --release
```

---

### Option 2: Manual Setup (If flutter_launcher_icons doesn't work)

#### For Android:

The icon placement locations:
```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png          (48×48)
├── mipmap-hdpi/ic_launcher.png          (72×72)
├── mipmap-xhdpi/ic_launcher.png         (96×96)
├── mipmap-xxhdpi/ic_launcher.png        (144×144)
└── mipmap-xxxhdpi/ic_launcher.png       (192×192)
```

**Steps:**
1. Open `spicehut_logo.png` in an image editor (Photoshop, GIMP, Figma, etc.)
2. Create/export versions at the sizes above
3. Save each version to the corresponding `mipmap-*` folder
4. Name each file `ic_launcher.png`

**Command Line Option (macOS/Linux):**
```bash
# Using ImageMagick (install first: brew install imagemagick)
convert assets/logo/spicehut_logo.png -define icon:auto-resize=48,72,96,144,192 android/app/src/main/res/mipmap-*/ic_launcher.png
```

#### For iOS:

1. Open `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
2. Create these image sizes (recommended spec):

```
20pt  = 20×20 (1x), 40×40 (2x), 60×60 (3x)
29pt  = 29×29 (1x), 58×58 (2x), 87×87 (3x)
40pt  = 40×40 (1x), 80×80 (2x), 120×120 (3x)
60pt  = 120×120 (2x), 180×180 (3x)
1024pt = 1024×1024 (1x) - for App Store
```

3. Drag the images into Xcode's AppIcon set, or manually place them in:
   ```
   ios/Runner/Assets.xcassets/AppIcon.appiconset/
   ```

---

## 🔍 Verification

### After Icon Generation:

**Check Android icons exist:**
```bash
ls -la "Flutter App Admin Side/android/app/src/main/res/mipmap-"*/ic_launcher.png
```

**Check iOS icons in Xcode:**
1. Open `ios/Runner.xcworkspace` (NOT .xcodeproj)
2. In Xcode: Runner → Assets.xcassets → AppIcon
3. Verify all icon slots are filled

### Test on Emulator/Device:
```bash
flutter clean
flutter pub get
flutter run
```

---

## ⚠️ Important Notes

### Image Requirements:
- **Format:** PNG with transparent background (recommended)
- **Quality:** High resolution (1024×1024 minimum for source)
- **Platform:** Should be square and center-aligned
- **Colors:** Ensure visibility on both light and dark backgrounds

### App Name Display:
If you want to change the app name displayed under the icon:

**Android:**
```xml
<!-- File: android/app/src/main/AndroidManifest.xml -->
<application android:label="SpiceHut Admin">
```

**iOS:**
```xml
<!-- File: ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key>
<string>SpiceHut Admin</string>
```

---

## 🎯 For Release Builds

Before submitting to App Store/Play Store:

**iOS (App Store):**
- Icon must be 1024×1024 pixels without any transparency border
- No rounded corners (iOS applies them automatically)

**Android (Play Store):**
- Icon should be 192×192 pixels for the base mdpi
- System will scale for other densities
- Must have full 8-bit alpha transparency support

---

## 📚 Configuration Files

### Current Configuration (`pubspec.yaml`):
```yaml
flutter_launcher_icons:
  image_path: "assets/logo/spicehut_logo.png"
  android:
    notification_icon: "ic_launcher"
  ios: true
```

### Advanced Options (Optional):
```yaml
flutter_launcher_icons:
  image_path: "assets/logo/spicehut_logo.png"
  image_path_ios: "assets/logo/spicehut_logo.png"
  image_path_android: "assets/logo/spicehut_logo.png"
  
  android: true
  ios: true
  
  min_sdk_android: 21
  
  android_adaptive_foreground: "assets/logo/spicehut_logo.png"
  android_adaptive_background: "#FFFFFF"
  android_adaptive_monochrome: "assets/logo/spicehut_logo.png"
```

---

## ❌ Troubleshooting

**Issue:** Icon not showing after build
- **Solution:** Run `flutter clean` then rebuild

**Issue:** flutter_launcher_icons command not found
- **Solution:** Run `flutter pub get` first

**Issue:** Transparent parts showing as white/black
- **Solution:** Ensure PNG has proper alpha channel; re-export from image editor

**Issue:** Icon looks pixelated on device
- **Solution:** Use higher resolution source image (1024×1024 minimum)

**Issue:** iOS app shows old icon after update
- **Solution:** 
  1. Delete build folder: `rm -rf ios/Pods ios/Podfile.lock`
  2. Run: `flutter clean && flutter pub get`
  3. Rebuild on device

---

## 🚀 Quick Commands Summary

```bash
# Setup
cd "Flutter App Admin Side"
flutter pub get

# Generate icons
flutter pub run flutter_launcher_icons

# Verify
ls android/app/src/main/res/mipmap-*/ic_launcher.png

# Test
flutter run

# Build for release
flutter build ios --release
flutter build appbundle --release
```

---

**✨ Icon setup complete! Your app icon is now set to the SpiceHut logo. ✨**
