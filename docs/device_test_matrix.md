# Device Test Matrix

Record one row per build/device combination. Replace `TBD` after physical or
emulator testing. Use the APK for direct installation; use the AAB only after
the future Play Console track is configured manually.

| Android version | Device/emulator | Screen | Architecture | Install | Core | Export | Backup/restore | Scanner | Issues |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Android 7.0 / API 24 | Oldest supported device/emulator | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Android 12 / API 31 | Mid-range device/emulator | Normal | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Android 16 / API 36 | Current API device/emulator | Normal | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Android 16 / API 36 | Small-screen device/emulator | Small | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

## Required Checks Per Row

- Install, launch, and uninstall behavior.
- First-run and offline core flow.
- Transaction, category, dashboard, search, filter, and Reports checks.
- Excel, Text, and PDF save/open checks.
- Backup, restore, invalid restore, and app restart.
- Upgrade over the previous build where available.
- Scanner checks only when the scanner remains exposed.
- Record severity and reproduction details for every issue.
