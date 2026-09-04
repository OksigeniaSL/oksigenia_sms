# Changelog

## 0.1.0

- Initial release. Sends a long message as a single concatenated Android SMS
  using only the `SEND_SMS` permission — never `READ_PHONE_STATE` — via
  `sendMultipartTextMessage` with sent-status intents.
- GSM-7 / UCS-2 aware splitting; never breaks a surrogate pair.
- Per-part send confirmation surfaced as `sent` / `failed` / `unknown`.
- Works on Android 12–17 and GrapheneOS, with no Google Play Services.
