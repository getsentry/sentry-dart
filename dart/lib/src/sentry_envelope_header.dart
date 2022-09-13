import 'protocol/sentry_id.dart';
import 'protocol/sdk_version.dart';
import 'sentry_trace_context_header.dart';

/// Header containing `SentryId` and `SdkVersion`.
class SentryEnvelopeHeader {
  SentryEnvelopeHeader(
    this.eventId,
    this.sdkVersion, {
    this.traceContext,
  });
  SentryEnvelopeHeader.newEventId()
      : eventId = SentryId.newId(),
        sdkVersion = null,
        traceContext = null;

  /// The identifier of encoded `SentryEvent`.
  final SentryId? eventId;

  /// The `SdkVersion` with which the envelope was send.
  final SdkVersion? sdkVersion;

  final SentryTraceContextHeader? traceContext;

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

    final tempTraceContext = traceContext;
    if (tempTraceContext != null) {
      json['trace'] = tempTraceContext.toJson();
    }

    return json;
  }
}
