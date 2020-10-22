import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import 'client_stub.dart'
    if (dart.library.html) 'browser_client.dart'
    if (dart.library.io) 'io_client.dart';
import 'protocol.dart';
import 'stack_trace.dart';
import 'transport/transport.dart';
import 'utils.dart';

/// Logs crash reports and events to the Sentry.io service.
abstract class SentryClient {
  /// Creates a new platform appropriate client.
  ///
  /// Creates an `SentryIOClient` if `dart:io` is available and a `SentryBrowserClient` if
  /// `dart:html` is available, otherwise it will throw an unsupported error.
  factory SentryClient(SentryOptions options) => createSentryClient(options);

  SentryClient.base(
    this.options, {
    @required this.transport,
  });

  @protected
  SentryOptions options;

  @visibleForTesting
  final Transport transport;

  /// Information about the current user.
  ///
  /// This information is sent with every logged event. If the value
  /// of this field is updated, all subsequent events will carry the
  /// new information.
  ///
  /// [Event.userContext] overrides the [User] context set here.
  ///
  /// See also:
  /// * https://docs.sentry.io/learn/context/#capturing-the-user
  User userContext;

  /// Reports an [event] to Sentry.io.
  Future<SentryId> captureEvent(
    SentryEvent event, {
    StackFrameFilter stackFrameFilter,
    Scope scope,
  }) async {
    event = _processEvent(event, eventProcessors: options.eventProcessors);

    event = _applyScope(event: event, scope: scope);

    final data = <String, dynamic>{
      'event_id': event.eventId.toString(),
    };

    if (options.environmentAttributes != null) {
      mergeAttributes(options.environmentAttributes.toJson(), into: data);
    }

    mergeAttributes(
      event.toJson(
        stackFrameFilter: stackFrameFilter,
        origin: transport.origin,
      ),
      into: data,
    );

    return transport.send(data);
  }

  /// Reports the [throwable] and optionally its [stackTrace] to Sentry.io.
  Future<SentryId> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    Scope scope,
  }) {
    final event = SentryEvent(
      exception: throwable,
      stackTrace: stackTrace,
      timestamp: options.clock(),
    );
    return captureEvent(event, scope: scope);
  }

  /// Reports the [template]
  Future<SentryId> captureMessage(
    String formatted, {
    SentryLevel level = SentryLevel.info,
    String template,
    List<dynamic> params,
    Scope scope,
  }) {
    final event = SentryEvent(
      message: Message(formatted, template: template, params: params),
      level: level,
      timestamp: options.clock(),
    );
    return captureEvent(event, scope: scope);
  }

  Future<void> close() async {
    options.httpClient?.close();
  }

  SentryEvent _processEvent(
    SentryEvent event, {
    dynamic hint,
    List<EventProcessor> eventProcessors,
  }) {
    for (final processor in eventProcessors) {
      try {
        event = processor(event, hint);
      } catch (err) {
        options.logger(
          SentryLevel.error,
          'An exception occurred while processing event by a processor : $err',
        );
      }
      if (event == null) {
        options.logger(SentryLevel.debug, 'Event was dropped by a processor');
        break;
      }
    }
    return event;
  }

  SentryEvent _applyScope({
    @required SentryEvent event,
    @required Scope scope,
  }) {
    if (scope != null) {
      // Merge the scope transaction.
      if (event.transaction == null) {
        event = event.copyWith(transaction: scope.transaction);
      }

      // Merge the user context.
      if (event.userContext == null) {
        event = event.copyWith(userContext: scope.user);
      }

      // Merge the scope fingerprint.
      if (event.fingerprint == null) {
        event = event.copyWith(fingerprint: scope.fingerprint);
      }

      // Merge the scope breadcrumbs.
      if (event.breadcrumbs == null) {
        event = event.copyWith(breadcrumbs: scope.breadcrumbs);
      }

      // TODO add tests
      // Merge the scope tags.
      event = event.copyWith(
          tags: scope.tags.map((key, value) => MapEntry(key, value))
            ..addAll(event.tags ?? {}));

      // Merge the scope extra.
      event = event.copyWith(
          extra: scope.extra.map((key, value) => MapEntry(key, value))
            ..addAll(event.extra ?? {}));

      // Merge the scope level.
      if (event.level == null) {
        event = event.copyWith(level: scope.level);
      }
    }
    return event;
  }
}
