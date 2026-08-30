# Finote Privacy Policy Draft

Last reviewed: 2026-08-30

Finote is an offline-first personal finance application. This document is a
release draft and must be published at a stable public URL before submission.

## Data Stored on the Device

Finote stores financial transactions, categories, notes, dates, app settings,
and security preferences locally on the device. The SQLite database remains
under the user's control.

Finote can also create local backup archives and user-requested Excel, Text,
and PDF reports. The user chooses where to save or share those files.

## Legacy Import

Finote reads a selected legacy Catatan Keuangan SQLite database locally and
does not modify or upload the source file.

## Receipt Scanner

The optional receipt scanner uses camera or gallery input and on-device OCR.
The user chooses when to use it. Images and OCR text are processed locally;
Finote does not send them to an AI service or cloud service. Temporary files
are cleaned when the workflow finishes where safe.

## Data Sharing and Collection

The current application has no account system, cloud sync, advertising,
analytics SDK, crash-reporting SDK, or application-owned network API. A
transitive Google ML Kit transport dependency contributes network permissions
to the merged release manifest; Finote does not send financial data, notes,
backups, exports, receipt images, or OCR text through that API.

When the user explicitly uses Android sharing or saves a file, Android and the
selected destination receive the file as directed by the user. Finote does
not control that destination's handling of the file.

## Permissions

The release manifest requests camera access only for the optional receipt
scanner. Backup, restore, import, and export use Android's system document
picker and do not require broad storage access.

## Security and Deletion

PIN verification data uses secure platform storage. Financial data stays in
the local database. Users can delete transactions through the app and remove
local app data or files through Android. Uninstalling Finote removes its
private app data according to Android behavior. User-saved exports and backups
must be removed by the user from their chosen destination.

## Changes and Contact

This policy will be updated when Finote's data behavior changes. Before Play
Console submission, replace this section with the publisher's support contact
and the effective policy URL.
