# Blood Bridge - Play Store Build Instructions

## Prerequisites

### 1. Install Android Studio
- Download: https://developer.android.com/studio
- Install and complete setup wizard
- Accept Android licenses: `flutter doctor --android-licenses`

### 2. Setup Environment Variables
Add to `~/.zshrc` or `~/.bash_profile`:
```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

Then reload: `source ~/.zshrc`

### 3. Verify Setup
```bash
flutter doctor
```
Should show Android toolchain installed ✓

---

## Build Release AAB (Play Store)

### Step 1: Clean Project
```bash
cd /Users/apple/Documents/Blood_Bridge/fyp
flutter clean
flutter pub get
```

### Step 2: Update Version
Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Format: major.minor.patch+buildNumber
```

### Step 3: Build AAB
```bash
flutter build appbundle --release
```

### Step 4: Locate File
AAB file will be at:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## Build APK (Testing Only - Not for Play Store)

```bash
flutter build apk --release
```

APK location:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## Upload to Play Store

### Option 1: Google Play Console (Manual)
1. Go to: https://play.google.com/console
2. Select "Blood Bridge" app
3. Go to "Production" → "Create new release"
4. Upload the `.aab` file
5. Fill release notes
6. Review and rollout

### Option 2: Using fastlane (Automated)
```bash
# Install fastlane
gem install fastlane

# Setup
cd android
fastlane init

# Deploy
fastlane deploy
```

---

## Troubleshooting

### Issue: "No Android SDK found"
**Solution:** Install Android Studio and run `flutter doctor`

### Issue: "Gradle build failed"
**Solution:** 
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Issue: "Signing key not found"
**Solution:** Check `android/key.properties` exists with keystore info

---

## Key Files to Check Before Build

✅ `pubspec.yaml` - Version number updated
✅ `android/app/build.gradle` - Version code matches
✅ `android/key.properties` - Signing key configured
✅ `lib/firebase_options.dart` - Firebase config correct
✅ `android/app/src/main/AndroidManifest.xml` - Permissions correct

---

## Version History

- v1.0.0+1 (April 11, 2026) - Initial release
- v1.0.0+2 (April 17, 2026) - Bug fixes
- v1.0.1+2 (Current) - Major updates:
  - Fixed photo storage (Firebase Storage)
  - Removed demo mode
  - Fixed registration flow
  - Added Enter key disable
  - Improved error handling
  - Fixed terminal crashes

---

## Notes

- Always test AAB on internal testing track first
- Keep old AAB files for rollback: `app-release-YYYY-MM-DD.aab`
- Increment version code with each upload
- Play Store requires AAB (not APK) for new apps

