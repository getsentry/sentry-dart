import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../utils/os_utils.dart';

@internal
class TelemetryEnricherIntegration implements Integration<SentryOptions> {
  static const spanEnricherIntegrationName = 'SpanEnricher';
  static const logEnricherIntegrationName = 'LogEnricher';

  SentryOptions? _options;

  late final void Function(OnBeforeCaptureSpanV2 event) _spanCallback =
      _enrichSpan;
  late final void Function(OnBeforeCaptureLog event) _logCallback = _enrichLog;

  @override
  void call(Hub hub, SentryOptions options) {
    _options = options;

    if (options.isTracingEnabled() &&
        options.traceLifecycle == SentryTraceLifecycle.streaming) {
      options.lifecycleRegistry
          .registerCallback<OnBeforeCaptureSpanV2>(_spanCallback);
      options.sdk.addIntegration(spanEnricherIntegrationName);
    }

    if (options.enableLogs) {
      options.lifecycleRegistry
          .registerCallback<OnBeforeCaptureLog>(_logCallback);
      options.sdk.addIntegration(logEnricherIntegrationName);
    }
  }

  @override
  void close() {
    final registry = _options?.lifecycleRegistry;
    registry?.removeCallback<OnBeforeCaptureSpanV2>(_spanCallback);
    registry?.removeCallback<OnBeforeCaptureLog>(_logCallback);
    _options = null;
  }

  void _enrichSpan(OnBeforeCaptureSpanV2 event) {
    final span = event.span;
    final options = _options;
    if (options == null) return;

    final enrichedAttributes =
        Map<String, SentryAttribute>.from(span.attributes);
    _enrichCommonAttributes(enrichedAttributes, options, event.scope);

    final segmentSpan = span.segmentSpan;
    enrichedAttributes.putIfAbsent(
      SemanticAttributesConstants.sentrySegmentName,
      () => SentryAttribute.string(segmentSpan.name),
    );
    enrichedAttributes.putIfAbsent(
      SemanticAttributesConstants.sentrySegmentId,
      () => SentryAttribute.string(segmentSpan.spanId.toString()),
    );

    span.setAttributes(enrichedAttributes);
  }

  void _enrichLog(OnBeforeCaptureLog event) {
    final log = event.log;
    final options = _options;
    final scope = event.scope;
    if (options == null) return;

    _enrichCommonAttributes(log.attributes, options, scope);

    final activeSpanId =
        options.traceLifecycle == SentryTraceLifecycle.streaming
            ? scope?.getActiveSpan()?.spanId
            : scope?.span?.context.spanId;

    if (activeSpanId != null) {
      log.attributes[SemanticAttributesConstants.sentryTraceParentSpanId] =
          SentryAttribute.string(activeSpanId.toString());
    }
  }

  /// Mutates the given [attributes] in place with common attributes.
  void _enrichCommonAttributes(
    Map<String, SentryAttribute> attributes,
    SentryOptions options,
    Scope? scope,
  ) {
    // Scope attributes
    if (scope != null) {
      for (final entry in scope.attributes.entries) {
        attributes.putIfAbsent(entry.key, () => entry.value);
      }
    }

    // SDK metadata
    attributes.putIfAbsent(
      SemanticAttributesConstants.sentrySdkName,
      () => SentryAttribute.string(options.sdk.name),
    );
    attributes.putIfAbsent(
      SemanticAttributesConstants.sentrySdkVersion,
      () => SentryAttribute.string(options.sdk.version),
    );

    // Environment
    final environment = options.environment;
    if (environment != null) {
      attributes.putIfAbsent(
        SemanticAttributesConstants.sentryEnvironment,
        () => SentryAttribute.string(environment),
      );
    }

    final release = options.release;
    if (release != null) {
      attributes.putIfAbsent(
        SemanticAttributesConstants.sentryRelease,
        () => SentryAttribute.string(release),
      );
    }

    // User attributes (gated by sendDefaultPii)
    if (options.sendDefaultPii) {
      final user = scope?.user;
      if (user != null) {
        if (user.id != null) {
          attributes.putIfAbsent(
            SemanticAttributesConstants.userId,
            () => SentryAttribute.string(user.id!),
          );
        }
        if (user.name != null) {
          attributes.putIfAbsent(
            SemanticAttributesConstants.userUsername,
            () => SentryAttribute.string(user.name!),
          );
        }
        if (user.email != null) {
          attributes.putIfAbsent(
            SemanticAttributesConstants.userEmail,
            () => SentryAttribute.string(user.email!),
          );
        }
      }
    }

    // OS info
    final os = getSentryOperatingSystem();

    if (os.name != null) {
      attributes.putIfAbsent(
        SemanticAttributesConstants.osName,
        () => SentryAttribute.string(os.name!),
      );
    }

    if (os.version != null) {
      attributes.putIfAbsent(
        SemanticAttributesConstants.osVersion,
        () => SentryAttribute.string(os.version!),
      );
    }
  }
}
