import 'package:meta/meta.dart';

import '../../sentry.dart';
import 'span/on_before_capture_span_v2.dart';
import 'span/sentry_span_v2.dart';

/// Integration that enriches telemetry with common attributes.
///
/// This integration adds attributes from the global scope.
@internal
class CommonAttributesEnricherIntegration
    implements Integration<SentryOptions> {
  static const integrationName = 'CommonAttributesEnricher';

  SentryOptions? _options;

  @override
  void call(Hub hub, SentryOptions options) {
    _options = options;

    if (!options.isTracingEnabled()) {
      options.log(
        SentryLevel.info,
        '$integrationName disabled: tracing is not enabled',
      );
      return;
    }

    options.lifecycleRegistry
        .registerCallback<OnBeforeCaptureSpanV2>(_enrichSpan);

    options.sdk.addIntegration(integrationName);
  }

  @override
  void close() {
    _options?.lifecycleRegistry
        .removeCallback<OnBeforeCaptureSpanV2>(_enrichSpan);
    _options = null;
  }

  void _enrichSpan(OnBeforeCaptureSpanV2 event) {
    final span = event.span;
    final scope = event.scope;
    final options = _options;

    if (options == null) return;

    final attributes = span.attributes;

    // 1. Merge scope attributes (user-set span attributes have priority)
    if (scope != null) {
      for (final entry in scope.attributes.entries) {
        if (!attributes.containsKey(entry.key)) {
          span.setAttribute(entry.key, entry.value);
        }
      }
    }

    // 2. Add SDK metadata attributes
    _setAttributeIfAbsent(
      span,
      'sentry.sdk.name',
      SentryAttribute.string(options.sdk.name),
    );
    _setAttributeIfAbsent(
      span,
      'sentry.sdk.version',
      SentryAttribute.string(options.sdk.version),
    );

    // 3. Add environment info
    final environment = options.environment;
    if (environment != null) {
      _setAttributeIfAbsent(
        span,
        'sentry.environment',
        SentryAttribute.string(environment),
      );
    }

    final release = options.release;
    if (release != null) {
      _setAttributeIfAbsent(
        span,
        'sentry.release',
        SentryAttribute.string(release),
      );
    }

    // 4. Add user attributes from scope
    if (scope != null) {
      final user = scope.user;
      if (user != null) {
        final id = user.id;
        if (id != null) {
          _setAttributeIfAbsent(span, 'user.id', SentryAttribute.string(id));
        }

        final name = user.name;
        if (name != null) {
          _setAttributeIfAbsent(
            span,
            'user.name',
            SentryAttribute.string(name),
          );
        }

        final email = user.email;
        if (email != null) {
          _setAttributeIfAbsent(
            span,
            'user.email',
            SentryAttribute.string(email),
          );
        }
      }
    }
  }

  void _setAttributeIfAbsent(
    RecordingSentrySpanV2 span,
    String key,
    SentryAttribute value,
  ) {
    if (!span.attributes.containsKey(key)) {
      span.setAttribute(key, value);
    }
  }
}
