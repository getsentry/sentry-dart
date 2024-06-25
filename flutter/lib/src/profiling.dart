import 'dart:async';

// ignore: implementation_imports
import 'package:sentry/src/profiling.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_envelope_item_header.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_item_type.dart';

import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';

// ignore: invalid_use_of_internal_member
class SentryNativeProfilerFactory implements SentryProfilerFactory {
  final SentryNativeBinding _native;
  final ClockProvider _clock;

  SentryNativeProfilerFactory(this._native, this._clock);

  static void attachTo(Hub hub, SentryNativeBinding native) {
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
      hub.profilerFactory = SentryNativeProfilerFactory(native, options.clock);
    }
  }

  @override
  SentryNativeProfiler? startProfiler(SentryTransactionContext context) {
    if (context.traceId == SentryId.empty()) {
      return null;
    }

    final startTime = _native.startProfiler(context.traceId);
    if (startTime == null) {
      return null;
    }
    return SentryNativeProfiler(_native, startTime, context.traceId, _clock);
  }
}

// ignore: invalid_use_of_internal_member
class SentryNativeProfiler implements SentryProfiler {
  final SentryNativeBinding _native;
  final int _starTimeNs;
  final SentryId _traceId;
  bool _finished = false;
  final ClockProvider _clock;

  SentryNativeProfiler(
      this._native, this._starTimeNs, this._traceId, this._clock);

  @override
  void dispose() {
    if (!_finished) {
      _finished = true;
      _native.discardProfiler(_traceId);
    }
  }

  @override
  Future<SentryNativeProfileInfo?> finishFor(
      SentryTransaction transaction) async {
    if (_finished) {
      return null;
    }
    _finished = true;

    // ignore: invalid_use_of_internal_member
    final transactionEndTime = transaction.timestamp ?? _clock();
    final duration = transactionEndTime.difference(transaction.startTimestamp);
    final endTimeNs = _starTimeNs + (duration.inMicroseconds * 1000);

    final payload =
        await _native.collectProfile(_traceId, _starTimeNs, endTimeNs);
    if (payload == null) {
      return null;
    }

    payload["transaction"]["id"] = transaction.eventId.toString();
    payload["transaction"]["trace_id"] = _traceId.toString();
    payload["transaction"]["name"] = transaction.transaction;
    payload["timestamp"] = transaction.startTimestamp.toIso8601String();
    return SentryNativeProfileInfo(payload);
  }
}

// ignore: invalid_use_of_internal_member
class SentryNativeProfileInfo implements SentryProfileInfo {
  final Map<String, dynamic> _payload;
  // ignore: invalid_use_of_internal_member
  late final List<int> _data = utf8JsonEncoder.convert(_payload);

  SentryNativeProfileInfo(this._payload);

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
