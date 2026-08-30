# Release Candidate Test Run: rc.1

## Candidate

- Product: Finote
- Proposed label: `v1.0.0-rc.1`
- `versionName`: `1.0.0`
- `versionCode`: `1`
- Build type: Android release
- Application ID: `com.finote.app`
- Target SDK: `36`
- Compile SDK: `37`
- Build date (UTC): `2026-08-30T11:50:36Z`
- Source commit at audit start: `1be62357918d5625bc8023b6888747bab79945ba`
- Git tag: none; tagging requires explicit user confirmation

## Reproduction

Run from a clean checkout of the candidate commit with the same Flutter/Dart
and Android SDK toolchain:

```bash
dart format .
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

Do not commit `android/key.properties`, keystores, or generated build output.
When a production upload key exists, copy `android/key.properties.example` to
`android/key.properties` outside version control and rebuild.

## Automated Results

- `dart format .`: PASS during Phase 5H validation.
- `flutter analyze`: PASS.
- `flutter test`: PASS, 125 tests.
- `flutter build apk --release`: PASS, 99,339,394 bytes.
- `flutter build appbundle --release`: PASS, 80,560,652 bytes.
- APK metadata: package `com.finote.app`, `1.0.0`, `versionCode 1`, target SDK 36.
- Artifact signature: WARNING, debug key used because no `android/key.properties` exists.

## Manual Results

Not run in this environment. Pending: device matrix, first-run, offline,
upgrade, export open/share, backup/restore lifecycle, and scanner decision.

## Known Limitations

- Production icon and branded splash are not final.
- Privacy policy has no public URL/contact details yet.
- Real historical migration fixture is not available.
- No Play Console upload, track, tester account, tag, or production release was created.
