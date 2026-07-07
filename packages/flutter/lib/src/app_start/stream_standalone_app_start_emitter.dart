// ignore_for_file: invalid_use_of_internal_member, experimental_member_use

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import 'app_start_info.dart';
import 'standalone_app_start_emitter.dart';
import 'stream_app_start_span_writer.dart';

@internal
final class StreamStandaloneAppStartEmitter
    implements StandaloneAppStartEmitter {
  StreamStandaloneAppStartEmitter({
    required Hub hub,
    StreamAppStartSpanWriter? writer,
  })  : _hub = hub,
        _writer = writer ?? StreamAppStartSpanWriter(hub: hub);

  final Hub _hub;
  final StreamAppStartSpanWriter _writer;

  @override
  Future<void> emit(AppStartInfo appStartInfo) async {
    final appStartType = SentryAttribute.string(appStartInfo.type.name);
    final root = _hub.startIdleSpan(
      'App Start',
      bindToScope: false,
      startTimestamp: appStartInfo.start,
      attributes: {
        SemanticAttributesConstants.sentryOp: SentryAttribute.string(
          SentrySpanOperations.appStart,
        ),
        SemanticAttributesConstants.sentryOrigin: SentryAttribute.string(
          SentryTraceOrigins.autoAppStart,
        ),
        SemanticAttributesConstants.appVitalsStartType: appStartType,
      },
    );

    _writer.writeStandalone(root, appStartInfo);
    _writer.finish(root, appStartInfo);
  }
}
