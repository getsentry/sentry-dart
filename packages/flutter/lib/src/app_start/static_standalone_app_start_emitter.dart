// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';

import '../../sentry_flutter.dart';
import 'app_start_info.dart';
import 'standalone_app_start_emitter.dart';
import 'static_app_start_span_writer.dart';

@internal
final class StaticStandaloneAppStartEmitter
    implements StandaloneAppStartEmitter {
  StaticStandaloneAppStartEmitter({
    required Hub hub,
    StaticAppStartSpanWriter? writer,
  })  : _hub = hub,
        _writer = writer ?? StaticAppStartSpanWriter(hub: hub);

  final Hub _hub;
  final StaticAppStartSpanWriter _writer;

  @override
  Future<void> emit(AppStartInfo appStartInfo) async {
    final transaction = _hub.startTransactionWithContext(
      SentryTransactionContext(
        'App Start',
        SentrySpanOperations.appStart,
        origin: SentryTraceOrigins.autoAppStart,
      ),
      startTimestamp: appStartInfo.start,
      waitForChildren: true,
      autoFinishAfter: const Duration(seconds: 30),
      // No trimEnd: the explicit finish timestamp below is authoritative;
      // trimming would let an out-of-range native span time stretch the
      // transaction past the measured app start end, making its duration
      // disagree with the app start measurement.
      onFinish: (transaction) =>
          _writer.writeStandaloneEncoding(transaction, appStartInfo),
    );
    if (transaction is! SentryTracer) {
      return;
    }

    await _writer.writeStandalone(transaction, appStartInfo);
    await transaction.finish(endTimestamp: appStartInfo.end);
  }
}
