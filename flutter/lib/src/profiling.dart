import 'dart:async';
import 'dart:io';

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

  NativeProfilerFactory(this._native);

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
      hub.profilerFactory = NativeProfilerFactory(SentryNative());
    }
  }

  @override
  NativeProfiler? startProfiling(SentryTransactionContext context) {
    if (context.traceId == SentryId.empty()) {
      return null;
    }

    final startTime = _native.startProfiling(context.traceId);

    // TODO we cannot await the future returned by a method channel because
    //  startTransaction() is synchronous. In order to make this code fully
    //  synchronous and actually start the profiler, we need synchronous FFI
    //  calls, see https://github.com/getsentry/sentry-dart/issues/1444
    //  For now, return immediately even though the profiler may not have started yet...
    return NativeProfiler(_native, startTime, context.traceId);
  }
}

// TODO this may move to the native code in the future - instead of unit-testing,
//      do an integration test once https://github.com/getsentry/sentry-dart/issues/1605 is done.
// ignore: invalid_use_of_internal_member
class NativeProfiler implements Profiler {
  final SentryNative _native;
  final Future<int?> _startTime;
  final SentryId _traceId;

  NativeProfiler(this._native, this._startTime, this._traceId);

  @override
  void dispose() {
    // TODO expose in the cocoa SDK
    // _startTime.then((_) => _native.discardProfiling(this._traceId));
  }

  @override
  Future<NativeProfileInfo?> finishFor(SentryTransaction transaction) async {
    final starTime = await _startTime;
    if (starTime == null) {
      return null;
    }

    final payload = await _native.collectProfile(_traceId, starTime);
    if (payload == null) {
      return null;
    }

    payload["transaction"] = <String, String?>{
      "id": transaction.eventId.toString(),
      "trace_id": _traceId.toString(),
      "name": transaction.transaction,
      // "active_thread_id" : [transaction.trace.transactionContext sentry_threadInfo].threadId
    };
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
