// ignore_for_file: invalid_use_of_internal_member, duplicate_ignore

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:sentry/src/sentry_envelope_item.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry/src/sdk_lifecycle_hooks.dart';
import '../../sentry_flutter.dart';
import '../sentry_flutter_options.dart';

/// Batches rrweb-style events into ~fixed-duration segments and uploads them
/// as Sentry replay envelopes.
class ReplaySegmentBatcher {
  ReplaySegmentBatcher(
    this._eventsStream, {
    Duration window = const Duration(seconds: 5),
    bool compress = false,
  })  : _window = window,
        _compress = compress;

  final Stream<Map<String, dynamic>> _eventsStream;
  final Duration _window;
  final bool _compress;

  final List<Map<String, dynamic>> _buffer = <Map<String, dynamic>>[];
  Timer? _timer;
  int _segmentId = 0;
  int? _segmentStartMs;
  StreamSubscription<Map<String, dynamic>>? _sub;
  final Set<String> _pendingErrorIds = <String>{};
  final Set<String> _pendingTraceIds = <String>{};
  SdkLifecycleCallback<OnBeforeSendEvent>? _beforeSendCb;
  String? _activeReplayId;

  void start() {
    stop();
    _sub = _eventsStream.listen(_onEvent);
    _timer = Timer.periodic(_window, (_) => _flush());

    // Collect error_ids and trace_ids for the segment via lifecycle hook.
    final options = Sentry.currentHub.options;
    _beforeSendCb = (OnBeforeSendEvent e) async {
      final ev = e.event;
      // Collect error event ids
      if (ev.exceptions?.isNotEmpty == true && ev.eventId != SentryId.empty()) {
        _pendingErrorIds.add(ev.eventId.toString());
      }
      // Collect trace ids from any event with trace context
      final trace = ev.contexts.trace;
      if (trace != null) {
        _pendingTraceIds.add(trace.traceId.toString());
      }
    };
    options.lifecycleRegistry
        .registerCallback<OnBeforeSendEvent>(_beforeSendCb!);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
    // Unregister lifecycle callback
    final options = Sentry.currentHub.options;
    if (_beforeSendCb != null) {
      options.lifecycleRegistry
          .removeCallback<OnBeforeSendEvent>(_beforeSendCb!);
      _beforeSendCb = null;
    }
    if (_buffer.isNotEmpty) {
      _flush();
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    _segmentStartMs ??= (event['timestamp'] as int?);
    // Basic rrweb schema validation and normalization
    final normalized = Map<String, dynamic>.from(event);
    if (normalized['timestamp'] is! int) {
      final ts = normalized['timestamp'];
      if (ts is num) normalized['timestamp'] = ts.toInt();
      if (normalized['timestamp'] is! int) {
        normalized['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    if (normalized['type'] is! int) return; // drop invalid
    _buffer.add(normalized);
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;

    print('caught: flushing');

    final options = Sentry.currentHub.options;
    // Ensure we have a replay id for correlation.
    SentryId replayId = Sentry.currentHub.scope.replayId ?? SentryId.newId();
    await Sentry.configureScope((scope) {
      // ignore: invalid_use_of_internal_member
      scope.replayId = replayId;
    });

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = _segmentStartMs ?? nowMs;

    // Build replay_event metadata (minimal)
    // Build error_ids/trace_ids from collected data since last flush
    final errorIds = List<String>.from(_pendingErrorIds);
    final traceIds = List<String>.from(_pendingTraceIds);
    if (traceIds.isEmpty) {
      // Fallback to current active trace id
      final scope = Sentry.currentHub.scope;
      final activeTraceId = scope.span?.context.traceId.toString() ??
          scope.propagationContext.traceId.toString();
      traceIds.add(activeTraceId);
    }

    // Reset segment counter if replay id changed (new session)
    final newReplayIdStr = replayId.toString();
    if (_activeReplayId != newReplayIdStr) {
      _activeReplayId = newReplayIdStr;
      _segmentId = 0;
    }

    final replayEvent = <String, dynamic>{
      'type': 'replay_event',
      'replay_id': replayId.toString(),
      'segment_id': _segmentId,
      'timestamp': nowMs / 1000.0,
      'replay_start_timestamp': startMs / 1000.0,
      'replay_type': 'session',
      // Server expects javascript-like replay stream semantics
      'platform': 'javascript',
      'environment': options.environment,
      'event_id': replayId.toString(),
      'sdk': {
        'name': options.sdk.name,
        'version': options.sdk.version,
        'integrations': <String>['Replay'],
      },
      'contexts': {
        'replay': {
          'session_sample_rate': (options is SentryFlutterOptions)
              ? options.replay.sessionSampleRate
              : 1.0,
          'error_sample_rate': (options is SentryFlutterOptions)
              ? options.replay.onErrorSampleRate
              : 0.0,
        }
      },
      // Collected associations for this segment
      'error_ids': errorIds,
      'trace_ids': traceIds,
      'urls': <String>[],
    };

    print('caught: buffer size ${_buffer.length}');
    // Recording data: prepend header line, then JSON array of events
    final segmentHeader = jsonEncode({'segment_id': _segmentId});
    // Ensure first segment includes a synthetic FullSnapshot (checkout) event
    final events = List<Map<String, dynamic>>.from(_buffer);
    if (_segmentId == 0 && events.every((e) => e['type'] != 2)) {
      // Try to infer canvas dimensions from the first canvas incremental event
      int pixelWidth = 2000;
      int pixelHeight = 2000;
      double? logicalWidth;
      double? logicalHeight;
      double? dpr;
      for (final ev in events) {
        final data = ev['data'];
        if (ev['type'] == 3 &&
            data is Map<String, dynamic> &&
            data['source'] == 9) {
          final pw = data['pixelWidth'];
          final ph = data['pixelHeight'];
          final lw = data['logicalWidth'];
          final lh = data['logicalHeight'];
          final ddpr = data['devicePixelRatio'];
          if (pw is num && ph is num) {
            pixelWidth = pw.toInt();
            pixelHeight = ph.toInt();
          }
          if (lw is num && lh is num) {
            logicalWidth = lw.toDouble();
            logicalHeight = lh.toDouble();
          }
          if (ddpr is num) {
            dpr = ddpr.toDouble();
          }
          break;
        }
      }
      // Fallback logical size from DPR if not provided explicitly
      if ((logicalWidth == null || logicalHeight == null) &&
          dpr != null &&
          dpr > 0) {
        logicalWidth = pixelWidth / dpr;
        logicalHeight = pixelHeight / dpr;
      }
      logicalWidth ??= pixelWidth.toDouble();
      logicalHeight ??= pixelHeight.toDouble();

      // Insert rrweb Meta frame first
      events.insert(0, {
        'type': 4, // Meta
        'timestamp': startMs,
        'data': {
          'href': 'about:blank',
          // rrweb expects viewport CSS dimensions here
          'width': logicalWidth.round(),
          'height': logicalHeight.round(),
        }
      });

      // Node ids: 0=Document, 1=html, 2=body, 3=canvas (must match incremental canvas event id)
      events.insert(1, {
        'type': 2, // Full snapshot
        'timestamp': startMs,
        'data': {
          'node': {
            'type': 0, // Document
            'childNodes': [
              {
                'type': 1,
                'name': 'html',
                'attributes': {'lang': 'en'},
                'childNodes': [
                  {
                    'type': 1,
                    'name': 'body',
                    'attributes': <String, dynamic>{},
                    'childNodes': [
                      {
                        'type': 1,
                        'name': 'canvas',
                        'attributes': {
                          'width': pixelWidth.toString(),
                          'height': pixelHeight.toString(),
                          'style':
                              'width: ${logicalWidth}px; height: ${logicalHeight}px; display: block;'
                        },
                        'id': kReplayCanvasNodeId
                      }
                    ],
                    'id': 2
                  }
                ],
                'id': 1
              }
            ],
            'id': 0
          },
          'initialOffset': {'left': 0, 'top': 0}
        }
      });
    }
    final recordingJson = jsonEncode(events);
    final recordingPayload = '$segmentHeader\n$recordingJson';

    final items = [
      SentryEnvelopeItem(
        SentryEnvelopeItemHeader(
          'replay_event',
          contentType: 'application/json',
        ),
        () => utf8.encode(jsonEncode(replayEvent)),
        originalObject: replayEvent,
      ),
      SentryEnvelopeItem(
        SentryEnvelopeItemHeader(
          'replay_recording',
          contentType:
              _compress ? 'application/octet-stream' : 'application/json',
        ),
        () => utf8.encode(recordingPayload),
        originalObject: recordingPayload,
      )
    ];
    // Build envelope
    final envelopeHeader = SentryEnvelopeHeader(
      // Use the replay id as envelope event id for easier cross-linking
      replayId,
      options.sdk,
      dsn: options.dsn,
    )..sentAt = DateTime.now();
    final envelope = SentryEnvelope(
      envelopeHeader,
      items,
    );

    log('header: ${envelopeHeader.toJson()}');
    log('item1: header: replay_event with application/json, payload: ${replayEvent}');
    log('item2: header: replay_recording with application/json, payload: ${recordingPayload}');

    // Send via configured transport
    await options.transport.send(envelope);

    // Prepare for next segment
    _buffer.clear();
    _segmentStartMs = null;
    _segmentId += 1;
    _pendingErrorIds.clear();
    _pendingTraceIds.clear();
  }
}
