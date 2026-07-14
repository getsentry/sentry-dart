import 'package:sentry_flutter/sentry_flutter.dart';

/// Runs startup work inside the active `Extended App Start` child.
///
/// The lifecycle-specific branches demonstrate how to add a nested span. In
/// application code only the branch matching `traceLifecycle` returns a span.
Future<void> runExtendedAppStartWork(
  Future<void> Function() initialize,
) async {
  SentryFlutter.extendAppStart();

  final staticChild = SentryFlutter.getExtendedAppStartSpan()?.startChild(
    'app.start.initialize',
    description: 'Initialize application dependencies',
  );
  final streamingParent = SentryFlutter.getExtendedAppStartSpanV2();
  final streamingChild = streamingParent == null
      ? null
      : Sentry.startInactiveSpan(
          'Initialize application dependencies',
          parentSpan: streamingParent,
          attributes: {
            'sentry.op': SentryAttribute.string('app.start.initialize'),
          },
        );

  try {
    await initialize();
  } finally {
    await staticChild?.finish();
    streamingChild?.end();
    SentryFlutter.finishExtendedAppStart();
  }
}
