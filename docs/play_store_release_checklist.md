# Play Store Release Checklist

## Application

- [x] Final name: Finote
- [x] Application ID: `com.finote.app`
- [x] `versionName`: `1.0.0`
- [x] `versionCode`: `1`
- [x] `targetSdk`: `36`
- [ ] Final production launcher icon and adaptive icon
- [ ] Branded splash assets
- [ ] Feature graphic
- [ ] Phone screenshots

## SDK and Compatibility

- [x] `compileSdk`: `37` (required by installed Android plugins)
- [x] `minSdk`: Flutter 3.47.2 toolchain value `24`
- [ ] Android 16/API 36 real-device smoke test
- [ ] Oldest supported Android device test
- [ ] Edge-to-edge and system-bar review

## Security

- [x] Release signing configuration supports `android/key.properties`
- [x] `key.properties`, keystores, and passwords are ignored by Git
- [ ] Generate and securely store upload key
- [ ] Configure Google Play App Signing
- [ ] Confirm release artifact is signed with upload key, not debug key
- [ ] Never commit signing secrets

The upload key authenticates uploads. Google Play App Signing manages the app
signing key used for distribution. `applicationId` is permanent after
publication; changing it creates a different Play application.

## Permissions

- [x] Main manifest contains only justified camera permission
- [x] No `MANAGE_EXTERNAL_STORAGE`
- [x] No broad storage permissions
- [x] Review transitive ML Kit transport permissions: release includes `INTERNET` and `ACCESS_NETWORK_STATE`
- [ ] Confirm camera prompt occurs only when scanner is used
- [ ] Recheck merged release manifest after dependency changes

## Privacy and Data Safety

- [x] Privacy policy draft: `docs/privacy_policy.md`
- [x] Data Safety draft: `docs/play_store_data_safety.md`
- [x] Network and analytics audit completed
- [ ] Publish privacy policy at a stable URL
- [ ] Complete Play Console Data Safety form
- [ ] Add support/contact details

## Quality

- [x] `flutter analyze`
- [x] `flutter test`
- [x] `flutter build apk --release`
- [x] `flutter build appbundle --release`
- [ ] Release APK physical-device smoke test
- [ ] Upgrade test with a previous build/database
- [ ] Large-data smoke test on Android

## Store

- [x] Listing draft: `docs/play_store_listing.md`
- [x] Release notes draft: `docs/release_notes_v1.0.md`
- [ ] Final descriptions
- [ ] Screenshots
- [ ] Feature graphic
- [ ] Contact details

## Testing

- [ ] Internal testing
- [ ] Closed testing
- [ ] Play Console pre-launch report review

Phase 5H covers testing and release workflow. This checklist does not
publish or upload anything automatically.
