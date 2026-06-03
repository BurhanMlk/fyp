# blood_bridge_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For Flutter development resources, check the [online documentation](https://docs.flutter.dev/) for tutorials, samples, and a complete API reference.

## Android release signing

Google Play rejects APK/AAB files signed with the debug keystore.
This project is configured to use a release keystore from `android/key.properties`.

1. Generate an upload keystore (one time):

	```bash
	keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
	```

2. Create `android/key.properties` from `android/key.properties.example` and set real values:

	```properties
	storePassword=YOUR_KEYSTORE_PASSWORD
	keyPassword=YOUR_KEY_PASSWORD
	keyAlias=upload
	storeFile=../app/upload-keystore.jks
	```

3. Build a release artifact:

	```bash
	flutter build appbundle --release
	```

	Or for APK:

	```bash
	flutter build apk --release
	```
