import 'dart:convert';

import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';

class SentryEnvelopeHeader {
  SentryEnvelopeHeader(this.eventId, this.sdkVersion);

  final SentryId? eventId;
  final SdkVersion? sdkVersion;

  String serialize() {
    final serializedMap = <String, dynamic>{};
    if (eventId != null) {
      serializedMap['event_id'] = eventId!.toString();
    }
    if (sdkVersion != null) {
      serializedMap['sdk'] = sdkVersion!.toJson();
    }
    return jsonEncode(serializedMap);
  }
}
