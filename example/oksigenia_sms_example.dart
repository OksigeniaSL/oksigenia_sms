// Copyright 2026 Oksigenia SL
// SPDX-License-Identifier: Apache-2.0

import 'package:oksigenia_sms/oksigenia_sms.dart';

/// Sends an emergency SMS to [contact] and prints the outcome.
///
/// The host app must already hold the runtime `SEND_SMS` permission before
/// calling this; the package requests no permissions of its own.
Future<void> sendSos(String contact) async {
  final result = await OksigeniaSms.send(
    to: contact,
    message: 'SOS - I need help.\n'
        'geo:40.4168,-3.7038\n'
        'https://maps.google.com/?q=40.4168,-3.7038',
  );

  switch (result.status) {
    case OksigeniaSmsStatus.sent:
      print('Delivered in ${result.parts} segment(s).');
    case OksigeniaSmsStatus.failed:
      print('Radio rejected it: ${result.error} '
          '(${result.okParts}/${result.parts} ok)');
    case OksigeniaSmsStatus.unknown:
      // Handed to the radio; no confirmation within the timeout. Usually still
      // delivered — do not re-send, or the recipient gets duplicates.
      print('Submitted to the radio; no confirmation within the timeout.');
  }
}
