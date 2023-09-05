import 'dart:async';

import 'package:sentry/sentry.dart';
// ignore: implementation_imports
import 'package:sentry/src/profiling.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_envelope_item_header.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_item_type.dart';

import 'sentry_native.dart';

// ignore: invalid_use_of_internal_member
class NativeProfilerFactory implements ProfilerFactory {
  final SentryNative _native;
  final ClockProvider _clock;

  NativeProfilerFactory(this._native, this._clock);

  static void attachTo(Hub hub) {
    // ignore: invalid_use_of_internal_member
    final options = hub.options;

    // ignore: invalid_use_of_internal_member
    if ((options.profilesSampleRate ?? 0.0) <= 0.0) {
      return;
    }

    if (options.platformChecker.isWeb) {
      return;
    }

    if (options.platformChecker.platform.isMacOS ||
        options.platformChecker.platform.isIOS) {
      // ignore: invalid_use_of_internal_member
      hub.profilerFactory =
          // ignore: invalid_use_of_internal_member
          NativeProfilerFactory(SentryNative(), options.clock);
    }
  }

  @override
  NativeProfiler? startProfiler(SentryTransactionContext context) {
    if (context.traceId == SentryId.empty()) {
      return null;
    }

    final startTime = _native.startProfiler(context.traceId);

    // TODO we cannot await the future returned by a method channel because
    //  startTransaction() is synchronous. In order to make this code fully
    //  synchronous and actually start the profiler, we need synchronous FFI
    //  calls, see https://github.com/getsentry/sentry-dart/issues/1444
    //  For now, return immediately even though the profiler may not have started yet...
    return NativeProfiler(_native, startTime, context.traceId, _clock);
  }
}

// TODO this may move to the native code in the future - instead of unit-testing,
//      do an integration test once https://github.com/getsentry/sentry-dart/issues/1605 is done.
// ignore: invalid_use_of_internal_member
class NativeProfiler implements Profiler {
  final SentryNative _native;
  final Future<int?> _startTime;
  final SentryId _traceId;
  bool _finished = false;
  final ClockProvider _clock;

  NativeProfiler(this._native, this._startTime, this._traceId, this._clock);

  @override
  void dispose() {
    if (!_finished) {
      _finished = true;
      _startTime.then((_) => _native.discardProfiler(_traceId));
    }
  }

  @override
  Future<NativeProfileInfo?> finishFor(SentryTransaction transaction) async {
    if (_finished) {
      return null;
    }
    _finished = true;

    final starTimeNs = await _startTime;
    if (starTimeNs == null) {
      return null;
    }

    // ignore: invalid_use_of_internal_member
    final transactionEndTime = transaction.timestamp ?? _clock();
    final duration = transactionEndTime.difference(transaction.startTimestamp);
    final endTimeNs = starTimeNs + (duration.inMicroseconds * 1000);

    final payload =
        await _native.collectProfile(_traceId, starTimeNs, endTimeNs);
    if (payload == null) {
      return null;
    }

    payload["transaction"]["id"] = transaction.eventId.toString();
    payload["transaction"]["trace_id"] = _traceId.toString();
    payload["transaction"]["name"] = transaction.transaction;
    payload["timestamp"] = transaction.startTimestamp.toIso8601String();
    return NativeProfileInfo(payload);
  }
}

// ignore: invalid_use_of_internal_member
class NativeProfileInfo implements ProfileInfo {
  final Map<String, dynamic> _payload;
  // ignore: invalid_use_of_internal_member
  late final List<int> _data = utf8JsonEncoder.convert(_payload);

  NativeProfileInfo(this._payload);

  @override
  SentryEnvelopeItem asEnvelopeItem() {
    final header = SentryEnvelopeItemHeader(
      SentryItemType.profile,
      () => Future.value(_data.length),
      contentType: 'application/json',
    );
    return SentryEnvelopeItem(header, () => Future.value(_data));
  }
}
