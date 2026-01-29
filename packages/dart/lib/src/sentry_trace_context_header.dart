import 'package:meta/meta.dart';

import 'protocol/access_aware_map.dart';
import 'protocol/sentry_id.dart';
import 'sentry_baggage.dart';

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

  /// Deserializes a [SentryTraceContextHeader] from JSON [Map].
  factory SentryTraceContextHeader.fromJson(Map<String, dynamic> data) {
    final json = AccessAwareMap(data);
    return SentryTraceContextHeader(
      SentryId.fromId(json['trace_id']),
      json['public_key'],
      release: json['release'],
      environment: json['environment'],
      userId: json['user_id'],
      transaction: json['transaction'],
      sampleRate: json['sample_rate'],
      sampled: json['sampled'],
      replayId:
          json['replay_id'] == null ? null : SentryId.fromId(json['replay_id']),
      unknown: json.notAccessed(),
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      ...?unknown,
      'trace_id': traceId.toString(),
      'public_key': publicKey,
      if (release != null) 'release': release,
      if (environment != null) 'environment': environment,
      if (userId != null) 'user_id': userId,
      if (transaction != null) 'transaction': transaction,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (sampled != null) 'sampled': sampled,
      if (replayId != null) 'replay_id': replayId.toString(),
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
    );
  }
}
