import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';

/// Header containing `SentryId` and `SdkVersion`.
class SentryEnvelopeHeader {
  SentryEnvelopeHeader(this.eventId, this.sdkVersion);
  SentryEnvelopeHeader.newEventId()
      : eventId = SentryId.newId(),
        sdkVersion = null;

  /// The identifier of encoded `SentryEvent`.
  final SentryId? eventId;

  /// The `SdkVersion` with which the envelope was send.
  final SdkVersion? sdkVersion;

  /// Header encoded as JSON
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    final tempEventId = eventId;
    if (tempEventId != null) {
      json['event_id'] = tempEventId.toString();
    }
    final tempSdkVersion = sdkVersion;
    if (tempSdkVersion != null) {
      json['sdk'] = tempSdkVersion.toJson();
    }
    return json;
  }
}
