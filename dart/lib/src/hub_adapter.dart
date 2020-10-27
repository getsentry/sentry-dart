import 'dart:async';

import 'package:sentry/src/protocol/breadcrumb.dart';
import 'package:sentry/src/protocol/sentry_event.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:sentry/src/protocol/sentry_level.dart';
import 'package:sentry/src/sentry.dart';
import 'package:sentry/src/sentry_client.dart';

import 'hub.dart';

/// Hub adapter to make Integrations testable
class HubAdapter implements Hub {
  HubAdapter._();

  static final HubAdapter _instance = HubAdapter._();

  factory HubAdapter() {
    return _instance;
  }

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) =>
      Sentry.addBreadcrumb(crumb, hint: hint);

  @override
  void bindClient(SentryClient client) => Sentry.bindClient(client);

  @override
  Future<SentryId> captureEvent(SentryEvent event, {dynamic hint}) =>
      Sentry.captureEvent(event, hint: hint);

  @override
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    dynamic hint,
  }) =>
      Sentry.captureException(
        throwable,
        stackTrace: stackTrace,
        hint: hint,
      );

  @override
  Future<SentryId> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
    String template,
    List params,
    dynamic hint,
  }) =>
      Sentry.captureMessage(
        message,
        level: level,
        template: template,
        params: params,
        hint: hint,
      );

  @override
  Hub clone() => Sentry.clone();

  @override
  void close() => Sentry.close();

  @override
  void configureScope(ScopeCallback callback) =>
      Sentry.configureScope(callback);

  @override
  bool get isEnabled => Sentry.isEnabled;

  @override
  SentryId get lastEventId => Sentry.lastEventId;
}
