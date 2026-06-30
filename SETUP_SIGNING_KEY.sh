#!/bin/bash
# Setup Android App Signing Key

echo "🔐 Setting up Android signing key..."

# Navigate to android directory
cd /Users/apple/Documents/Blood_Bridge/fyp/android

# Generate keystore
echo "📝 Generating keystore..."
keytool -genkey -v -keystore app/upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass bloodbridge123 \
  -keypass bloodbridge123 \
  -dname "CN=Blood Bridge, OU=Development, O=Blood Bridge, L=Islamabad, ST=Punjab, C=PK"

# Create key.properties
echo "📄 Creating key.properties..."
cat > key.properties << EOF
storePassword=bloodbridge123
keyPassword=bloodbridge123
keyAlias=upload
storeFile=../app/upload-keystore.jks
EOF

echo "✅ Signing key setup complete!"
echo ""
echo "Files created:"
echo "  - android/app/upload-keystore.jks"
echo "  - android/key.properties"
echo ""
echo "⚠️  IMPORTANT: Keep these files secure!"
echo "⚠️  Do NOT commit key.properties to git!"
echo ""
echo "Now run: flutter build appbundle --release"

