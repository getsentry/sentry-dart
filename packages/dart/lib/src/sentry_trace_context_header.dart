import 'package:meta/meta.dart';

import '../sentry.dart';
import 'protocol/access_aware_map.dart';
import 'utils/sample_rate_format.dart';

class SentryTraceContextHeader {
  SentryTraceContextHeader(
    this.traceId,
    this.publicKey, {
    this.release,
    this.environment,
    this.userId,
    this.transaction,
    this.sampleRate,
    this.sampleRand,
    this.sampled,
    this.unknown,
    this.replayId,
    this.orgId,
  });

  final SentryId traceId;
  final String publicKey;
  final String? release;
  final String? environment;
  final String? userId;
  final String? transaction;
  final String? sampleRate;
  final String? sampleRand;
  final String? sampled;

  @internal
  final Map<String, dynamic>? unknown;

  @internal
  SentryId? replayId;

  /// The organization ID associated with this trace.
  final String? orgId;

  /// Deserializes a [SentryTraceContextHeader] from JSON [Map].
  factory SentryTraceContextHeader.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    final traceId = json.readString('trace_id');
    final replayId = json.readString('replay_id');
    return SentryTraceContextHeader(
      traceId != null ? SentryId.fromId(traceId) : const SentryId.empty(),
      json.readString('public_key') ?? '',
      release: json.readString('release'),
      environment: json.readString('environment'),
      userId: json.readString('user_id'),
      transaction: json.readString('transaction'),
      sampleRate: json.readString('sample_rate'),
      sampled: json.readString('sampled'),
      replayId: replayId != null ? SentryId.fromId(replayId) : null,
      orgId: json.readString('org_id'),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'trace_id': traceId.toString(),
      'public_key': publicKey,
      'release': ?release,
      'environment': ?environment,
      'user_id': ?userId,
      'transaction': ?transaction,
      'sample_rate': ?sampleRate,
      'sampled': ?sampled,
      'replay_id': ?replayId?.toString(),
      'org_id': ?orgId,
    };
  }

  SentryBaggage toBaggage() {
    final baggage = SentryBaggage({});
    baggage.setTraceId(traceId.toString());
    baggage.setPublicKey(publicKey);

    if (release != null) {
      baggage.setRelease(release!);
    }
    if (environment != null) {
      baggage.setEnvironment(environment!);
    }
    if (userId != null) {
      baggage.setUserId(userId!);
    }
    if (transaction != null) {
      baggage.setTransaction(transaction!);
    }
    if (sampleRate != null) {
      baggage.setSampleRate(sampleRate!);
    }
    if (sampleRand != null) {
      baggage.setSampleRand(sampleRand!);
    }
    if (sampled != null) {
      baggage.setSampled(sampled!);
    }
    if (replayId != null) {
      baggage.setReplayId(replayId.toString());
    }
    if (orgId != null) {
      baggage.setOrgId(orgId!);
    }
    return baggage;
  }

  factory SentryTraceContextHeader.fromBaggage(SentryBaggage baggage) {
    return SentryTraceContextHeader(
      // TODO: implement and use proper get methods here
      SentryId.fromId(baggage.get('sentry-trace_id').toString()),
      baggage.get('sentry-public_key').toString(),
      release: baggage.get('sentry-release'),
      environment: baggage.get('sentry-environment'),
      replayId: baggage.getReplayId(),
      orgId: baggage.getOrgId(),
    );
  }

  /// Creates a [SentryTraceContextHeader] from a [RecordingSentrySpanV2].
  ///
  /// Uses the segment span's name as the transaction name.
  factory SentryTraceContextHeader.fromRecordingSpan(
    RecordingSentrySpanV2 span,
    SentryOptions options,
    SentryId? replayId,
  ) {
    final sampleRateFormat = SampleRateFormat();
    String? formatRate(double? value) =>
        value != null ? sampleRateFormat.format(value) : null;

    return SentryTraceContextHeader(
      span.traceId,
      options.parsedDsn.publicKey,
      release: options.release,
      environment: options.environment,
      transaction: span.segmentSpan.name,
      sampleRate: formatRate(span.samplingDecision.sampleRate),
      sampleRand: span.samplingDecision.sampleRand?.toString(),
      sampled: span.samplingDecision.sampled.toString(),
      replayId: replayId,
      orgId: options.effectiveOrgId,
    );
  }
}
