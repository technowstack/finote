# Google Play Data Safety Draft

Last reviewed: 2026-08-30

Source code audit found no Firebase, Supabase, analytics, crash-reporting, or
application HTTP client. The merged release manifest includes `INTERNET` and
`ACCESS_NETWORK_STATE` through the transitive Google ML Kit transport
dependency. Finote has no configured remote endpoint; re-audit this if the
dependency changes.

## Data Types

| Play category | Collected by Finote | Shared by Finote | Notes |
| --- | --- | --- | --- |
| Financial info | No | No | Transactions, amounts, categories, notes, and balances stay local. |
| App activity | No | No | No remote event or usage tracking. |
| Files and documents | No | No | User-selected backups/imports and generated exports stay local unless the user chooses Android sharing. |
| Photos and videos | No | No | Receipt images are selected for local scanner processing only. |
| Device or other identifiers | No | No | No account, advertising ID, or app analytics identifier is used. |
| Diagnostics | No | No | No crash or diagnostics SDK sends data. |

## Security Answers

- Data collected by Finote: none in the current application flow. The
  transitive transport dependency is not used by Finote to send user data.
- Data shared by Finote: none automatically. User-directed Android file sharing
  is an explicit user action and must be reviewed against the destination's
  behavior when completing Play Console forms.
- Encryption in transit: not applicable to Finote's local-only processing;
  Finote does not transmit these data types.
- Deletion: users can delete local records and app data. Files saved outside
  app-private storage are controlled by the user and must be deleted there.
- Optional data: receipt images/OCR are optional and local-only.

These answers must be rechecked if dependencies, SDK configuration, or data
flows change before Play Console submission.
