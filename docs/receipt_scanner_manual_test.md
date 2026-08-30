# Receipt Scanner Manual Test Matrix

Use only dummy, synthetic, or redacted receipts. Do not commit real receipt
photos or OCR text.

## Camera and Gallery

- Camera permission denied: show an Indonesian permission message and do not crash.
- Camera permission permanently denied: show the settings action.
- Camera photo selected: show a preview, then discard it on cancel.
- Gallery photo selected: show a preview and keep the gallery file untouched.
- Unreadable or missing image: disable recognition and show a retry/change-photo path.

## OCR and Review

- Clear receipt: show OCR text and open an editable expense draft.
- Empty OCR result: show `Struk belum berhasil dibaca.` with retry and manual-entry actions.
- Synthetic minimarket, restaurant, fuel, and pharmacy receipts: verify merchant, date,
  total, tax/discount, and receipt number where present.
- Quantity item such as `KOPI 2 x 5.000 10.000`: verify quantity, unit price, and line total.
- Missing total: show the total warning and prevent saving until a valid amount is entered.
- Itemized mismatch: show a reconciliation warning without blocking manual correction.

## Save and Privacy

- Save a reviewed receipt draft: verify one `receipt_scan` transaction is created.
- Attempt duplicate save: verify the save guard prevents a second transaction.
- Cancel or replace a camera image: verify the temporary file is removed.
- Cancel or replace a gallery image: verify the original gallery file remains.
- Confirm no receipt image, raw OCR text, or OCR result is uploaded or logged.
