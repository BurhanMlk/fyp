# Quick AAB Build Guide (Without Android Studio)

## Option 1: Use Codemagic (Fastest - 5 minutes)

### Steps:
1. Go to: https://codemagic.io/start/
2. Sign up with GitHub account
3. Click "Add application"
4. Connect your GitHub repository (or upload project)
5. Select "Flutter App"
6. Click "Start new build"
7. Select "Release" build
8. Download AAB from "Artifacts" after build completes

**FREE:** 500 build minutes/month

---

## Option 2: Use GitHub Actions (Automatic)

### Steps:
1. Push code to GitHub
2. Add this file: `.github/workflows/build.yml`
3. Commit and push
4. GitHub will automatically build AAB
5. Download from "Actions" tab

**FREE:** Unlimited for public repos

---

## Option 3: Use Online Flutter Compiler

### AppFlowy Build Service:
- Visit: https://appflowy.io
- Upload project
- Build AAB online
- Download

---

## Option 4: Docker (If you have Docker)

```bash
# Pull Flutter Docker image
docker pull cirrusci/flutter:stable

# Run build in container
docker run --rm -v $(pwd):/project -w /project cirrusci/flutter:stable \
  sh -c "flutter pub get && flutter build appbundle --release"

# AAB will be in build/app/outputs/bundle/release/
```

---

## Option 5: Use Friend's Windows/Linux Machine

### Transfer Files:
```bash
# Compress project
cd /Users/apple/Documents/Blood_Bridge/
tar -czf fyp.tar.gz fyp/

# Transfer to Windows/Linux
# On that machine:
tar -xzf fyp.tar.gz
cd fyp
flutter build appbundle --release

# Copy back the AAB file from:
# build/app/outputs/bundle/release/app-release.aab
```

---

## Recommended: Codemagic

**Why?**
- ✅ No installation needed
- ✅ Builds in 5-10 minutes
- ✅ Free for open source
- ✅ Supports both Android & iOS
- ✅ Direct Play Store upload

**Current AAB Files Available:**
- `app-release-2026-04-11.aab` (59MB)
- `app-release-2026-04-17.aab` (59MB)

⚠️ **Note:** These don't include latest changes (photo storage fix, crash fixes, etc.)

