import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/app_start/app_start_span_kind.dart';

void main() {
  group('$AppStartSpanKind', () {
    test('uses the agreed startup names and operations', () {
      expect(
        AppStartSpanKind.values.map(
          (kind) => (kind.description, kind.operation),
        ),
        [
          ('Sentry Initialization', 'app.start.sentry_init'),
          ('Root Widget Attachment', 'app.start.root_widget_attachment'),
          ('Frame Build', 'app.start.frame_build'),
          ('Frame Rasterization', 'app.start.frame_raster'),
        ],
      );
    });
  });
}
