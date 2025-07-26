// ignore_for_file: invalid_use_of_internal_member

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart';

import '../../sentry_flutter.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

/// Handles Flutter Web app start performance measurement using Performance API.
///
/// This integration automatically captures browser navigation timing spans that are
/// meaningful for Flutter Web applications:
/// - DNS lookup, TCP connect, SSL handshake
/// - HTTP request/response (TTFB and Flutter bundle download)
/// - DOM processing and resource loading
///
/// Unlike native mobile apps, Flutter Web renders to canvas, so traditional DOM
/// timing events are less meaningful. This integration focuses on network timing
/// and resource loading which directly impact Flutter Web startup performance.
class WebAppStartIntegration extends Integration<SentryFlutterOptions> {
  WebAppStartIntegration();

  late Hub _hub;
  late SentryFlutterOptions _options;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _hub = hub;
    _options = options;

    if (!options.platform.isWeb) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appStartEnd = options.clock();
      _measureAppStart(appStartEnd);
    });
  }

  void _measureAppStart(DateTime appStartEnd) {
    try {
      final timing = window.performance
          .getEntriesByType('navigation')
          .getProperty(0.toJS) as PerformanceNavigationTiming;
      final timeOrigin = window.performance.timeOrigin;

      if (timing.startTime == 0 && timeOrigin == 0) {
        _options.log(SentryLevel.debug, 'Navigation start time not available');
        return;
      }

      _createAppStartTransaction(
        timing: timing,
        timeOrigin: timeOrigin,
        appStartEnd: appStartEnd,
      );
    } catch (e) {
      _options.log(
          SentryLevel.warning, 'Failed to measure Flutter Web app start: $e');
    }
  }

  void _createAppStartTransaction({
    required PerformanceNavigationTiming timing,
    required double timeOrigin,
    required DateTime appStartEnd,
  }) {
    final appStartTime =
        DateTime.fromMillisecondsSinceEpoch(timeOrigin.toInt());
    print('diff: ${appStartEnd.difference(appStartTime).inMilliseconds}');

    // Create transaction context
    final transactionContext = SentryTransactionContext(
      'app.start.pageload',
      'Flutter Web App Start',
    );

    // Create idle transaction that auto-finishes after 3 seconds
    // All spans are created and finished immediately since timing data is historical
    final transaction = _hub.startTransactionWithContext(transactionContext,
        startTimestamp: appStartTime,
        autoFinishAfter: Duration(seconds: 3),
        waitForChildren: true,
        trimEnd: true);

    if (transaction is! SentryTracer) {
      return;
    }

    final sentryTracer = transaction;

    print('attach');

    final child = sentryTracer.startChild('ui.load.initial-display',
        startTimestamp:
            DateTime.fromMicrosecondsSinceEpoch((timeOrigin * 1000).toInt()));
    child.finish(endTimestamp: appStartEnd);
    // Add browser navigation spans
    _attachBrowserNavigationSpans(
        sentryTracer, timing, timeOrigin, appStartEnd);

    // Add resource timing spans for individual assets
    _attachResourceTimingSpans(sentryTracer, timeOrigin);

    // Add measurements
    final totalDuration = appStartEnd.difference(appStartTime);
    sentryTracer.measurements['app_start_pageload'] = SentryMeasurement(
      'app_start_pageload',
      totalDuration.inMilliseconds,
      unit: DurationSentryMeasurementUnit.milliSecond,
    );
  }

  void _attachBrowserNavigationSpans(
    SentryTracer transaction,
    PerformanceNavigationTiming timing,
    double timeOrigin,
    DateTime appStartEnd,
  ) {
    final traceId = transaction.context.traceId;
    final parentSpanId = transaction.context.spanId;

    // Helper to create browser spans with proper timing
    SentrySpan? createBrowserSpan(
      String operation,
      String description,
      double startTime,
      double endTime,
    ) {
      if (startTime == 0 || endTime == 0 || endTime < startTime) {
        return null;
      }

      // Convert Performance API timing (relative to timeOrigin) to absolute timestamps
      // timeOrigin is absolute epoch time, timing values are relative to navigation start
      final absoluteStartTime = timeOrigin + startTime;
      final absoluteEndTime = timeOrigin + endTime;

      final span = SentrySpan(
        transaction,
        SentrySpanContext(
          operation: operation,
          description: description,
          parentSpanId: parentSpanId,
          traceId: traceId,
        ),
        _hub,
        startTimestamp: DateTime.fromMicrosecondsSinceEpoch(
          (absoluteStartTime * 1000).toInt(),
        ),
      );

      // Finish span immediately since all timing data is historical
      span.finish(
          endTimestamp: DateTime.fromMicrosecondsSinceEpoch(
        (absoluteEndTime * 1000).toInt(),
      ));
      return span;
    }

    // Cache span - Time spent retrieving from browser cache
    // Calculated as the time between fetchStart and domainLookupStart
    final cacheSpan = createBrowserSpan(
      'browser',
      'cache',
      timing.fetchStart,
      timing.domainLookupStart,
    );
    if (cacheSpan != null) transaction.children.add(cacheSpan);

    // DNS lookup - Most meaningful for Flutter Web (network to get assets)
    final dnsSpan = createBrowserSpan(
      'browser',
      'DNS',
      timing.domainLookupStart,
      timing.domainLookupEnd,
    );
    print('dnsSpan: $dnsSpan');

    if (dnsSpan != null) transaction.children.add(dnsSpan);

    // TCP connect - Meaningful for Flutter Web
    final connectSpan = createBrowserSpan(
      'browser',
      'Connect',
      timing.connectStart,
      timing.connectEnd,
    );
    if (connectSpan != null) transaction.children.add(connectSpan);

    // SSL handshake (if HTTPS) - Meaningful for Flutter Web
    if (timing.secureConnectionStart > 0) {
      final sslSpan = createBrowserSpan(
        'browser',
        'SSL',
        timing.secureConnectionStart,
        timing.connectEnd,
      );
      if (sslSpan != null) transaction.children.add(sslSpan);
    }

    // HTTP request - Very meaningful (TTFB for Flutter bundle)
    final requestSpan = createBrowserSpan(
      'browser',
      'Request',
      timing.requestStart,
      timing.responseStart,
    );
    if (requestSpan != null) transaction.children.add(requestSpan);

    // HTTP response - Meaningful (Flutter bundle download)
    final responseSpan = createBrowserSpan(
      'browser',
      'Response',
      timing.responseStart,
      timing.responseEnd,
    );
    if (responseSpan != null) transaction.children.add(responseSpan);

    // DOM Interactive - Less meaningful for Flutter Web but still tracked
    final domInteractiveSpan = createBrowserSpan(
      'browser',
      'DOM Interactive',
      timeOrigin,
      timing.domInteractive,
    );
    if (domInteractiveSpan != null) {
      transaction.children.add(domInteractiveSpan);
    }

    // Load complete - Meaningful (all Flutter assets loaded)
    final loadSpan = createBrowserSpan(
      'browser',
      'Load Complete',
      timing.loadEventStart,
      timing.loadEventEnd,
    );
    if (loadSpan != null) transaction.children.add(loadSpan);

    // final loadToFirstFrameSpan = createBrowserSpan('browser',
    //     'Load Complete to First Frame', timing.loadEventEnd, appStartEnd);
    // if (loadSpan != null) transaction.children.add(loadSpan);

    final absoluteLoadEventStartTime = timeOrigin + timing.loadEventStart;

    final child = transaction.startChild('browser',
        description: 'Load Complete To First Frame',
        startTimestamp: _preciseDateTime(absoluteLoadEventStartTime));
    child.finish(endTimestamp: appStartEnd);
  }

  /// Adds resource timing spans for individual assets loaded during pageload
  void _attachResourceTimingSpans(SentryTracer transaction, double timeOrigin) {
    try {
      final resourceEntries = window.performance.getEntriesByType('resource');
      final resources = <PerformanceResourceTiming>[];

      for (int i = 0; i < resourceEntries.length; i++) {
        final entry = resourceEntries.getProperty(i.toJS);
        if (entry != null) {
          resources.add(entry as PerformanceResourceTiming);
        }
      }

      for (final resource in resources) {
        final resourceSpan =
            _createResourceSpan(transaction, resource, timeOrigin);
        if (resourceSpan != null) {
          transaction.children.add(resourceSpan);
        }
      }
    } catch (e) {
      _options.log(
          SentryLevel.debug, 'Failed to create resource timing spans: $e');
    }
  }

  /// Creates a resource span from PerformanceResourceTiming entry
  SentrySpan? _createResourceSpan(
    SentryTracer transaction,
    PerformanceResourceTiming resource,
    double timeOrigin,
  ) {
    // Skip if timing data is incomplete
    if (resource.startTime == 0 ||
        resource.responseEnd == 0 ||
        resource.responseEnd < resource.startTime) {
      return null;
    }

    // Determine resource type from initiatorType or URL
    final resourceType = _getResourceType(resource);
    final operation = 'resource.$resourceType';

    // Use resource name (URL) as description, but truncate if too long
    final description = _truncateUrl(resource.name);

    // Calculate absolute timestamps
    final absoluteStartTime = timeOrigin + resource.startTime;
    final absoluteEndTime = timeOrigin + resource.responseEnd;

    final span = SentrySpan(
      transaction,
      SentrySpanContext(
        operation: operation,
        description: description,
        parentSpanId: transaction.context.spanId,
        traceId: transaction.context.traceId,
      ),
      _hub,
      startTimestamp: DateTime.fromMicrosecondsSinceEpoch(
        (absoluteStartTime * 1000).toInt(),
      ),
    );

    // Add resource size data
    _addResourceData(span, resource);

    // Finish span immediately since timing data is historical
    span.finish(
      endTimestamp: DateTime.fromMicrosecondsSinceEpoch(
        (absoluteEndTime * 1000).toInt(),
      ),
    );

    return span;
  }

  /// Determines resource type from initiatorType or URL extension
  String _getResourceType(PerformanceResourceTiming resource) {
    final initiatorType = resource.initiatorType;

    // Use initiatorType if available and meaningful
    if (initiatorType.isNotEmpty &&
        !['other', 'navigation'].contains(initiatorType)) {
      return initiatorType;
    }

    // Fallback to URL extension analysis for Flutter Web assets
    final url = resource.name.toLowerCase();

    // Flutter Web specific assets
    if (url.contains('main.dart.js') || url.contains('.dart.js')) {
      return 'script.dart';
    }
    if (url.contains('flutter_service_worker.js')) {
      return 'script.serviceworker';
    }
    if (url.contains('flutter.js')) {
      return 'script.flutter';
    }
    if (url.contains('canvaskit')) {
      return 'script.canvaskit';
    }

    // Standard web asset types
    if (url.endsWith('.js')) return 'script';
    if (url.endsWith('.css')) return 'css';
    if (url.contains('.woff') || url.contains('.ttf') || url.contains('.otf')) {
      return 'font';
    }
    if (url.contains('.png') ||
        url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.gif') ||
        url.contains('.svg') ||
        url.contains('.webp')) {
      return 'img';
    }
    if (url.contains('.wasm')) return 'wasm';
    if (url.contains('.json')) return 'fetch';

    return 'other';
  }

  /// Adds resource size and performance data to span
  void _addResourceData(SentrySpan span, PerformanceResourceTiming resource) {
    // Transfer size (compressed size over network)
    if (resource.transferSize > 0) {
      span.setData('http.response_transfer_size', resource.transferSize);
    }

    // Encoded body size (compressed response body)
    if (resource.encodedBodySize > 0) {
      span.setData('http.response_content_length', resource.encodedBodySize);
    }

    // Decoded body size (uncompressed response body)
    if (resource.decodedBodySize > 0) {
      span.setData(
          'http.decoded_response_content_length', resource.decodedBodySize);
    }

    // Resource URL
    span.setData('url', resource.name);

    // Resource type
    if (resource.initiatorType.isNotEmpty) {
      span.setData('resource.initiator_type', resource.initiatorType);
    }

    // Cache hit detection
    if (resource.transferSize == 0 && resource.encodedBodySize > 0) {
      span.setTag('resource.from_cache', 'true');
    }
  }

  /// Truncates URL for span description to keep it readable
  String _truncateUrl(String url) {
    const maxLength = 100;
    if (url.length <= maxLength) return url;

    // Try to keep meaningful parts of URL
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        if (fileName.length < maxLength) {
          return '.../$fileName';
        }
      }
    }

    return '${url.substring(0, maxLength - 3)}...';
  }

  /// Converts high-precision double timestamp to DateTime while preserving sub-millisecond precision
  DateTime _preciseDateTime(double timestampMs) {
    // Split into milliseconds and microseconds for maximum precision
    final milliseconds = timestampMs.floor();
    final microseconds = ((timestampMs - milliseconds) * 1000).round();

    return DateTime.fromMillisecondsSinceEpoch(milliseconds)
        .add(Duration(microseconds: microseconds));
  }

  @override
  void close() {
    // Cleanup if needed
  }
}
