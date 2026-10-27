// Copyright 2026 Oksigenia SL <dev@oksigenia.cc>
// SPDX-License-Identifier: Apache-2.0

/// A permission-minimal Android SMS sender for Flutter.
///
/// Sends a long message as a single concatenated Android SMS using only the
/// `SEND_SMS` permission — never `READ_PHONE_STATE`. See [OksigeniaSms.send].
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// Outcome of a send.
///
/// - [sent]: every SMS part reported `RESULT_OK` from the radio.
/// - [failed]: at least one part reported an error code (see [OksigeniaSmsResult.error]).
///   `limit_exceeded` means someone denied Android's rate-limit confirmation
///   (see [OksigeniaSmsRateLimit]).
/// - [unknown]: no delivery result arrived within the timeout. The message was
///   handed to the radio and, in practice, usually still goes out — we just
///   couldn't confirm it via the sent-status callback. The exception: parts
///   beyond Android's rate limit wait for a confirmation that may never come,
///   so check [OksigeniaSms.rateLimit] before trusting `unknown` for those.
enum OksigeniaSmsStatus { sent, failed, unknown }

/// Android's per-app SMS rate limit (`sms_outgoing_check_max_count`).
///
/// Once an app has sent this many SMS parts within the check period, Android
/// holds every further part behind a system "Allow / Deny" dialog with no
/// timeout. Only the default SMS app is exempt. LineageOS exposes the value in
/// Trust → SMS message limit, where "Always confirm" stores 0. Android reads
/// it once when its telephony stack starts, so on many phones (GrapheneOS, for
/// one) a change only takes effect after a restart; some ROMs apply it at once.
class OksigeniaSmsRateLimit {
  /// Android's default when the setting is absent (AOSP `SmsUsageMonitor`).
  static const int defaultMaxCount = 30;

  /// The configured limit, or null if unset or unreadable on this ROM.
  final int? maxCount;

  /// The configured check period in milliseconds, or null if unset or
  /// unreadable.
  final int? intervalMs;

  /// False if the ROM refused to let the app read the setting.
  final bool readable;

  /// Creates a rate limit as read from the system settings.
  const OksigeniaSmsRateLimit({
    this.maxCount,
    this.intervalMs,
    this.readable = true,
  });

  /// The limit Android applies: [maxCount], or [defaultMaxCount] when unset.
  int get effectiveMaxCount => maxCount ?? defaultMaxCount;

  /// True when every SMS needs confirmation (LineageOS "Always confirm").
  bool get alwaysConfirm => effectiveMaxCount <= 0;

  /// True if sending [parts] SMS parts in one burst stays within the limit.
  bool allows(int parts) => parts <= effectiveMaxCount;

  @override
  String toString() =>
      'OksigeniaSmsRateLimit(max=${maxCount ?? 'default $defaultMaxCount'}, '
      'intervalMs=${intervalMs ?? 'default'}${readable ? '' : ', unreadable'})';
}

/// Result of [OksigeniaSms.send].
class OksigeniaSmsResult {
  /// Aggregated status across all parts.
  final OksigeniaSmsStatus status;

  /// How many SMS segments the message was split into.
  final int parts;

  /// How many segments reported `RESULT_OK`.
  final int okParts;

  /// Human-readable code of the first failing part, if any (e.g. `no_service`).
  final String? error;

  /// Creates a result with the aggregated [status] and per-part counts.
  const OksigeniaSmsResult({
    required this.status,
    required this.parts,
    required this.okParts,
    this.error,
  });

  /// True only when every part was confirmed sent.
  bool get ok => status == OksigeniaSmsStatus.sent;

  @override
  String toString() =>
      'OksigeniaSmsResult(${status.name}, $okParts/$parts parts${error != null ? ', error=$error' : ''})';
}

/// A permission-minimal Android SMS sender.
///
/// It splits the message itself into single-segment parts and hands them to
/// `SmsManager.sendMultipartTextMessage` together with sent-status
/// `PendingIntent`s. That path needs only `SEND_SMS` — never
/// `READ_PHONE_STATE`. `SmsManager.divideMessage`, by contrast, calls
/// `getGroupIdLevel1()` internally on Android 12+/GrapheneOS and throws a
/// `SecurityException` when the app doesn't hold `READ_PHONE_STATE`. The
/// recipient still receives one concatenated message.
///
/// The app must already hold the runtime `SEND_SMS` permission; this package
/// declares no permissions of its own.
class OksigeniaSms {
  OksigeniaSms._();

  static const MethodChannel _channel = MethodChannel('oksigenia_sms');

  /// Sends [message] to [to] as a single concatenated SMS.
  ///
  /// Waits up to [timeout] for the per-part sent results before returning; on
  /// timeout the result is [OksigeniaSmsStatus.unknown] (the message was still
  /// submitted to the radio).
  static Future<OksigeniaSmsResult> send({
    required String to,
    required String message,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final res = await _channel.invokeMapMethod<String, dynamic>('send', {
      'to': to,
      'message': message,
      'timeoutMs': timeout.inMilliseconds,
    });
    final m = res ?? const <String, dynamic>{};
    return OksigeniaSmsResult(
      status: OksigeniaSmsStatus.values.firstWhere(
        (s) => s.name == (m['status'] as String? ?? 'unknown'),
        orElse: () => OksigeniaSmsStatus.unknown,
      ),
      parts: (m['parts'] as int?) ?? 0,
      okParts: (m['okParts'] as int?) ?? 0,
      error: m['error'] as String?,
    );
  }

  /// Number of SMS parts [send] uses for [message] — what Android's rate limit
  /// charges for each recipient.
  static Future<int> partCount(String message) async =>
      await _channel.invokeMethod<int>('partCount', {'message': message}) ?? 0;

  /// Reads Android's per-app SMS rate limit. See [OksigeniaSmsRateLimit].
  static Future<OksigeniaSmsRateLimit> rateLimit() async {
    final m = await _channel.invokeMapMethod<String, dynamic>('rateLimit') ??
        const <String, dynamic>{};
    return OksigeniaSmsRateLimit(
      maxCount: m['maxCount'] as int?,
      intervalMs: m['intervalMs'] as int?,
      readable: (m['readable'] as bool?) ?? true,
    );
  }
}
