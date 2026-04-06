# Google Play Release Checklist

1. Update pubspec.yaml version
2. Run flutter clean
3. Run flutter pub get
4. Run flutter build appbundle
5. Upload build/app/outputs/bundle/release/app-release.aab to Google Play

Note: the build number after the + must increase every upload.