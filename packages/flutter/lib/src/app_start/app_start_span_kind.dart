// ignore_for_file: invalid_use_of_internal_member
import 'package:meta/meta.dart';
import '../../sentry_flutter.dart';

/// Shared vocabulary for measured startup children in both trace formats.
@internal
enum AppStartSpanKind {
  sentryInit,
  rootWidgetAttachment,
  frameBuild,
  frameRaster,
}

@internal
extension AppStartSpanKindSpans on AppStartSpanKind {
  String get description => switch (this) {
    AppStartSpanKind.sentryInit => 'Sentry Initialization',
    AppStartSpanKind.rootWidgetAttachment => 'Root Widget Attachment',
    AppStartSpanKind.frameBuild => 'Frame Build',
    AppStartSpanKind.frameRaster => 'Frame Rasterization',
  };
  String get operation => switch (this) {
    AppStartSpanKind.sentryInit => SentrySpanOperations.appStartSentryInit,
    AppStartSpanKind.rootWidgetAttachment =>
      SentrySpanOperations.appStartRootWidgetAttachment,
    AppStartSpanKind.frameBuild => SentrySpanOperations.appStartFrameBuild,
    AppStartSpanKind.frameRaster => SentrySpanOperations.appStartFrameRaster,
  };
  String? get threadName => switch (this) {
    AppStartSpanKind.rootWidgetAttachment ||
    AppStartSpanKind.frameBuild => 'ui',
    AppStartSpanKind.frameRaster => 'raster',
    AppStartSpanKind.sentryInit => null,
  };
}
