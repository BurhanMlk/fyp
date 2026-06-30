#!/bin/bash
# Install Android Command Line Tools (Minimum for AAB build)

echo "🔧 Installing Android Command Line Tools..."

# Download Android Command Line Tools
cd ~/Downloads
curl -O https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip

# Create SDK directory
mkdir -p ~/Library/Android/sdk/cmdline-tools
cd ~/Library/Android/sdk/cmdline-tools

# Extract
unzip ~/Downloads/commandlinetools-mac-11076708_latest.zip
mv cmdline-tools latest

# Set environment variables
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc

# Reload
source ~/.zshrc

# Install required packages
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

echo "✅ Android SDK Installed!"
echo "Now run: cd /Users/apple/Documents/Blood_Bridge/fyp && flutter build appbundle --release"

