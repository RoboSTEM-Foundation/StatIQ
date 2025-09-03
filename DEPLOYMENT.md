# Deployment Guide - statIQ

This guide explains how to build and deploy the VEX IQ RoboScout app for iOS and Android devices.

## 📱 Mobile App Deployment

### Prerequisites

#### For Android:
- Android Studio installed
- Android SDK configured
- Valid Android keystore for signing

#### For iOS:
- macOS computer
- Xcode installed
- Apple Developer account
- Valid provisioning profile

### Building for Android

#### 1. Generate Android Keystore
```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

#### 2. Configure Signing
Create `android/key.properties`:
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=upload-keystore.jks
```

#### 3. Build APK
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Split APKs for different architectures
flutter build apk --split-per-abi --release
```

#### 4. Build App Bundle (Recommended for Play Store)
```bash
flutter build appbundle --release
```

### Building for iOS

#### 1. Open iOS Project
```bash
open ios/Runner.xcworkspace
```

#### 2. Configure Signing in Xcode
- Select Runner project
- Go to Signing & Capabilities
- Select your team
- Update bundle identifier if needed

#### 3. Build iOS App
```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release
```

#### 4. Archive for App Store
- Open Xcode
- Select Product > Archive
- Follow App Store Connect instructions

### Testing on Physical Devices

#### Android Device
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect device via USB
4. Run: `flutter run --release`

#### iOS Device
1. Connect iPhone/iPad via USB
2. Trust the computer on your device
3. Run: `flutter run --release`

### App Store Deployment

#### Google Play Store
1. Create developer account
2. Upload APK or App Bundle
3. Fill in store listing details
4. Submit for review

#### Apple App Store
1. Create App Store Connect account
2. Create new app
3. Upload build via Xcode
4. Fill in app information
5. Submit for review

## 🔧 Configuration

### App Icons
Replace the default icons in:
- `android/app/src/main/res/mipmap-*`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset`

### App Name
The app name is configured in:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

### Version Management
Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # version_name+version_code
```

## 🚀 Continuous Integration

### GitHub Actions Example
Create `.github/workflows/build.yml`:
```yaml
name: Build and Deploy
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.2.3'
    - run: flutter pub get
    - run: flutter test
    - run: flutter build apk --release
    - run: flutter build ios --release --no-codesign
```

## 📊 Analytics and Monitoring

### Firebase Integration
1. Create Firebase project
2. Add `google-services.json` (Android)
3. Add `GoogleService-Info.plist` (iOS)
4. Add Firebase dependencies to `pubspec.yaml`

### Crash Reporting
Consider adding:
- Firebase Crashlytics
- Sentry
- Bugsnag

## 🔐 Security Considerations

### API Keys
- Store API keys securely
- Use environment variables
- Never commit keys to version control

### Code Obfuscation
```bash
# Android
flutter build apk --obfuscate --split-debug-info=build/debug-info

# iOS
flutter build ios --obfuscate --split-debug-info=build/debug-info
```

## 📈 Performance Optimization

### Build Optimization
```bash
# Enable R8 optimization for Android
flutter build apk --release --obfuscate

# Enable bitcode for iOS
flutter build ios --release --bitcode
```

### App Size Optimization
- Use ProGuard rules
- Enable code shrinking
- Optimize images and assets
- Use vector graphics where possible

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Device Testing
- Test on multiple screen sizes
- Test on different OS versions
- Test offline functionality
- Test API error scenarios

## 📝 Release Notes

### Version 1.0.0
- Initial release
- VEX IQ MS/ES support
- Custom statIQ Score™ system
- Team and event management
- Modern Material Design 3 UI

### Future Versions
- Advanced analytics
- Match predictions
- Export functionality
- Push notifications
- Social features

## 🆘 Troubleshooting

### Common Issues

#### Build Failures
- Clean build: `flutter clean && flutter pub get`
- Check dependencies: `flutter doctor`
- Verify signing configuration

#### Device Connection Issues
- Check USB debugging (Android)
- Trust computer (iOS)
- Restart adb: `adb kill-server && adb start-server`

#### Performance Issues
- Enable performance profiling
- Check memory usage
- Optimize image assets
- Review API calls

## 📞 Support

For deployment issues:
- Check Flutter documentation
- Review platform-specific guides
- Contact development team
- Check GitHub issues

---

**statIQ** - Ready for mobile deployment! 🚀 