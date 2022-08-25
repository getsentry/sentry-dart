import 'dart:async';

import 'feature_flags/feature_flag_context.dart';
import 'feature_flags/feature_flag_info.dart';
import 'protocol.dart';
import 'scope.dart';
import 'sentry_client.dart';
import 'sentry_envelope.dart';
import 'sentry_user_feedback.dart';

class NoOpSentryClient implements SentryClient {
  NoOpSentryClient._();

  static final NoOpSentryClient _instance = NoOpSentryClient._();

  factory NoOpSentryClient() {
    return _instance;
  }

  @override
  Future<SentryId> captureEvent(
    SentryEvent event, {
    dynamic stackTrace,
    Scope? scope,
    dynamic hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureException(
    dynamic exception, {
    dynamic stackTrace,
    Scope? scope,
    dynamic hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureMessage(
    String? message, {
    SentryLevel? level,
    String? template,
    List<dynamic>? params,
    Scope? scope,
    dynamic hint,
  }) async =>
      SentryId.empty();

  @override
  Future<SentryId> captureEnvelope(SentryEnvelope envelope) async =>
      SentryId.empty();

  @override
  Future<void> captureUserFeedback(SentryUserFeedback userFeedback) async {}

  @override
  Future<void> close() async {}

  @override
  Future<SentryId> captureTransaction(
    SentryTransaction transaction, {
    Scope? scope,
  }) async =>
      SentryId.empty();

  @override
  Future<T?> getFeatureFlagValueAsync<T>(
    String key, {
    Scope? scope,
    T? defaultValue,
    FeatureFlagContextCallback? context,
  }) async =>
      null;

  @override
  T? getFeatureFlagValue<T>(
    String key, {
    Scope? scope,
    T? defaultValue,
    FeatureFlagContextCallback? context,
  }) =>
      null;

  @override
  Future<FeatureFlagInfo?> getFeatureFlagInfo(
    String key, {
    Scope? scope,
    FeatureFlagContextCallback? context,
  }) async =>
      null;

  @override
  Future<void> requestFeatureFlags() async {}
}
