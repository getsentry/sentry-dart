import 'package:meta/meta.dart';

import 'protocol/sentry_id.dart';
import 'sentry_baggage.dart';
import 'sentry_options.dart';

@experimental
class SentryTraceContextHeader {
  SentryTraceContextHeader(
    this.traceId,
    this.publicKey, {
    this.release,
    this.environment,
    this.userId,
    this.userSegment,
    this.transaction,
    this.sampleRate,
  });

  final SentryId traceId;
  final String publicKey;
  final String? release;
  final String? environment;
  final String? userId;
  final String? userSegment;
  final String? transaction;
  final String? sampleRate;

  /// Deserializes a [SentryTraceContextHeader] from JSON [Map].
  factory SentryTraceContextHeader.fromJson(Map<String, dynamic> json) {
    return SentryTraceContextHeader(
      SentryId.fromId(json['trace_id']),
      json['public_key'],
      release: json['release'],
      environment: json['environment'],
      userId: json['user_id'],
      userSegment: json['user_segment'],
      transaction: json['transaction'],
      sampleRate: json['sample_rate'],
    );
  }

  /// Produces a [Map] that can be serialized to JSON.
  Map<String, dynamic> toJson() {
    return {
      'trace_id': traceId.toString(),
      'public_key': publicKey,
      if (release != null) 'release': release,
      if (environment != null) 'environment': environment,
      if (userId != null) 'user_id': userId,
      if (userSegment != null) 'user_segment': userSegment,
      if (transaction != null) 'transaction': transaction,
      if (sampleRate != null) 'sample_rate': sampleRate,
    };
  }

  SentryBaggage toBaggage({
    SentryLogger? logger,
  }) {
    final baggage = SentryBaggage({}, logger: logger);
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
    if (userSegment != null) {
      baggage.setUserSegment(userSegment!);
    }
    if (transaction != null) {
      baggage.setTransaction(transaction!);
    }
    if (sampleRate != null) {
      baggage.setSampleRate(sampleRate!);
    }

    return baggage;
  }
}
