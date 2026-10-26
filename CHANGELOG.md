# Changelog

## 0.2.0

- Add `OksigeniaSms.rateLimit()` and `OksigeniaSmsRateLimit`: reads Android's
  per-app SMS rate limit (`sms_outgoing_check_max_count`; LineageOS exposes it
  as Trust → SMS message limit). Past it, Android holds messages behind an
  Allow / Deny dialog with no timeout, so an unattended sender should check it.
- Add `OksigeniaSms.partCount()`: how many parts `send()` uses for a message,
  which is what that limit charges per recipient.
- Name the rate-limit and short-code result codes (`limit_exceeded`,
  `short_code_not_allowed`, `short_code_never_allowed`) instead of `code_N`.
- Copyright notices now read Oksigenia SL <dev@oksigenia.cc>.

## 0.1.1

- Trim the pubspec description to pub.dev's 60–180 character range.
- Add an `example/` and document the library and result constructor.
- No API or behaviour changes (pub.dev quality/score only).

## 0.1.0

- Initial release. Sends a long message as a single concatenated Android SMS
  using only the `SEND_SMS` permission — never `READ_PHONE_STATE` — via
  `sendMultipartTextMessage` with sent-status intents.
- GSM-7 / UCS-2 aware splitting; never breaks a surrogate pair.
- Per-part send confirmation surfaced as `sent` / `failed` / `unknown`.
- Works on Android 12–17 and GrapheneOS, with no Google Play Services.
