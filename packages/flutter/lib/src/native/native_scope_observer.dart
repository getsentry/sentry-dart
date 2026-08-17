import 'dart:async';

import 'package:sentry/sentry.dart';

import 'sentry_native_binding.dart';

class NativeScopeObserver implements ScopeObserver, HintAwareScopeObserver {
  NativeScopeObserver(this._native, this._options);

  final SentryNativeBinding _native;
  final SentryOptions _options;

  @override
  FutureOr<void> setContexts(String key, value) {
    // ignore: invalid_use_of_internal_member
    if (Contexts.defaultFields.contains(key)) {
      try {
        final json = (value as dynamic).toJson();
        return _native.setContexts(key, json);
      } catch (_) {
        _options.log(
          SentryLevel.error,
          "Failed to set context '$key' with value '$value'.",
        );
      }
    } else {
      return _native.setContexts(key, value);
    }
  }

  @override
  FutureOr<void> removeContexts(String key) {
    return _native.removeContexts(key);
  }

  @override
  FutureOr<void> setUser(SentryUser? user) {
    return _native.setUser(user);
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) {
    return addBreadcrumbWithHint(breadcrumb, Hint());
  }

  @override
  FutureOr<void> addBreadcrumbWithHint(Breadcrumb breadcrumb, Hint hint) async {
    final replayRequestId = breadcrumb.data?['replay_request_id'];
    if (replayRequestId is String) {
      // ignore: invalid_use_of_internal_member
      final request = hint.get(TypeCheckHint.replayNetworkRequestDetail);
      // ignore: invalid_use_of_internal_member
      final response = hint.get(TypeCheckHint.replayNetworkResponseDetail);
      if (request != null || response != null) {
        // Populate the replay detail cache before the breadcrumb becomes
        // visible on the native Scope. Session Replay can build a segment
        // from a background thread as soon as the breadcrumb lands in the
        // Scope; doing this the other way around leaves a window where the
        // breadcrumb is visible but its detail hasn't been cached yet,
        // so the replay segment would never pick it up.
        await _native.captureReplayNetworkDetail(
          replayRequestId,
          request: request is Map<String, dynamic> ? request : null,
          response: response is Map<String, dynamic> ? response : null,
        );
      }
    }

    await _native.addBreadcrumb(breadcrumb);
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    return _native.clearBreadcrumbs();
  }

  @override
  Future<void> setExtra(String key, dynamic value) async {
    await _native.setExtra(key, value);
  }

  @override
  Future<void> removeExtra(String key) async {
    await _native.removeExtra(key);
  }

  @override
  Future<void> setTag(String key, String value) async {
    await _native.setTag(key, value);
  }

  @override
  Future<void> removeTag(String key) async {
    await _native.removeTag(key);
  }
}
