#!/bin/bash
# ============================================================
# Blood Bridge - SHA-1 Fingerprint Extractor
# Run this script to get SHA-1 & SHA-256 fingerprints
# needed for Firebase Google Sign-In on Android.
# ============================================================

echo "=============================================="
echo "  Blood Bridge - SHA-1 Fingerprint Tool"
echo "=============================================="
echo ""

# Paths
KEYSTORE_DIR="$(cd "$(dirname "$0")/../android/app" && pwd)"
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

# --- Debug Keystore ---
echo "[1] DEBUG KEYSTORE"
echo "    Location: $DEBUG_KEYSTORE"
if [ -f "$DEBUG_KEYSTORE" ]; then
    echo ""
    keytool -list -v -keystore "$DEBUG_KEYSTORE" -storepass android -alias androiddebugkey 2>/dev/null | grep -E "SHA1:|SHA-1:|SHA256:" | sed 's/^/    /'
else
    echo "    ⚠️  Debug keystore NOT FOUND at $DEBUG_KEYSTORE"
fi

echo ""

# --- Release Keystore ---
KEY_PROPERTIES="$KEYSTORE_DIR/key.properties"
if [ -f "$KEY_PROPERTIES" ]; then
    STORE_PASS=$(grep "storePassword" "$KEY_PROPERTIES" | cut -d'=' -f2 | tr -d ' ')
    KEY_ALIAS=$(grep "keyAlias" "$KEY_PROPERTIES" | cut -d'=' -f2 | tr -d ' ')
    STORE_FILE=$(grep "storeFile" "$KEY_PROPERTIES" | cut -d'=' -f2 | tr -d ' ')
    
    # Resolve relative path
    if [[ "$STORE_FILE" == ../* ]]; then
        STORE_PATH="$KEYSTORE_DIR/$STORE_FILE"
    else
        STORE_PATH="$STORE_FILE"
    fi

    echo "[2] RELEASE KEYSTORE"
    echo "    Location: $STORE_PATH"
    echo "    Alias:    $KEY_ALIAS"
    if [ -f "$STORE_PATH" ] && [ -n "$STORE_PASS" ] && [ -n "$KEY_ALIAS" ]; then
        echo ""
        keytool -list -v -keystore "$STORE_PATH" -storepass "$STORE_PASS" -alias "$KEY_ALIAS" 2>/dev/null | grep -E "SHA1:|SHA-1:|SHA256:" | sed 's/^/    /'
    else
        echo "    ⚠️  Could not read release keystore."
    fi
else
    echo "[2] RELEASE KEYSTORE"
    echo "    ⚠️  key.properties not found at $KEY_PROPERTIES"
fi

echo ""
echo "=============================================="
echo "  HOW TO ADD TO FIREBASE CONSOLE:"
echo "=============================================="
echo ""
echo "  1. Go to: https://console.firebase.google.com"
echo "  2. Select project: bloodbridge-62261"
echo "  3. Go to: Project Settings → General"
echo "  4. Scroll to 'Your apps' → Select Android app"
echo "  5. Under 'SHA certificate fingerprints', click 'Add fingerprint'"
echo "  6. Paste the SHA-1 value(s) from above"
echo "  7. Click Save"
echo "  8. Download the updated google-services.json"
echo "  9. Replace: android/app/google-services.json"
echo ""
echo "  ⚠️  You MUST add BOTH Debug AND Release SHA-1!"
echo "=============================================="
