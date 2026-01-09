import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'telemetry/span/sentry_span_v2.dart';

@internal
typedef SdkLifecycleCallback<T extends SdkLifecycleEvent> = FutureOr<void>
    Function(T event);

@internal
abstract class SdkLifecycleEvent {}

/// Holds and dispatches SDK lifecycle events in a type-safe way.
/// These are meant to be used internally and are not part of public api.
@internal
class SdkLifecycleRegistry {
  SdkLifecycleRegistry(this._options);

  final SentryOptions _options;
  final _lifecycleCallbacks = <Type, List<Function>>{};

  Map<Type, List<Function>> get lifecycleCallbacks => _lifecycleCallbacks;

  void registerCallback<T extends SdkLifecycleEvent>(
      SdkLifecycleCallback<T> callback) {
    _lifecycleCallbacks[T] ??= [];
    _lifecycleCallbacks[T]?.add(callback);
  }

  void removeCallback<T extends SdkLifecycleEvent>(
      SdkLifecycleCallback<T> callback) {
    final callbacks = _lifecycleCallbacks[T];
    callbacks?.remove(callback);
  }

  FutureOr<void> dispatchCallback<T extends SdkLifecycleEvent>(T event) {
    final callbacks = _lifecycleCallbacks[event.runtimeType];
    if (callbacks == null || callbacks.isEmpty) {
      // Return synchronously when there are no callbacks to avoid unnecessary async boundary
      return null;
    }
    return _dispatchCallbackAsync(event, callbacks);
  }

  Future<void> _dispatchCallbackAsync<T extends SdkLifecycleEvent>(
      T event, List<Function> callbacks) async {
    for (final cb in callbacks) {
      try {
        final result = (cb as SdkLifecycleCallback<T>)(event);
        if (result is Future) {
          await result;
        }
      } catch (exception, stackTrace) {
        _options.log(
          SentryLevel.error,
          'The SDK lifecycle callback threw an exception',
          exception: exception,
          stackTrace: stackTrace,
        );
        if (_options.automatedTestMode) {
          rethrow;
        }
      }
    }
  }
}

@internal
class OnBeforeCaptureLog extends SdkLifecycleEvent {
  OnBeforeCaptureLog(this.log, this.scope);

  final SentryLog log;

  /// The current scope, providing access to scope attributes, user info, etc.
  /// May be null if no scope was provided during capture.
  final Scope? scope;
}

@internal
class OnBeforeSendEvent extends SdkLifecycleEvent {
  OnBeforeSendEvent(this.event, this.hint);

  final SentryEvent event;
  final Hint hint;
}

/// Dispatched when a sampled span is started.
@internal
class OnSpanStart extends SdkLifecycleEvent {
  OnSpanStart(this.span);

  final ISentrySpan span;
}

/// Dispatched when a sampled span is finished.
@internal
class OnSpanFinish extends SdkLifecycleEvent {
  OnSpanFinish(this.span);

  final ISentrySpan span;
}

/// Dispatched before a [RecordingSentrySpanV2] is captured and buffered.
@internal
class OnBeforeCaptureSpanV2 extends SdkLifecycleEvent {
  OnBeforeCaptureSpanV2(this.span, this.scope);

  /// The span being captured. Callbacks can modify this span's attributes.
  final RecordingSentrySpanV2 span;

  /// The current scope, providing access to scope attributes, user info, etc.
  /// May be null if no scope was provided during capture.
  final Scope? scope;
}
