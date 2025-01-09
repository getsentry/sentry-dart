import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:benchmarking/benchmarking.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screenshot/widget_filter.dart';

// Measures the time it takes to load a fixed number of assets into an
// immutable buffer to later be decoded by skia.
Future<void> execute() async {
  await benchmarkWidgets((WidgetTester tester) async {
    await tester.pumpWidget(
      SentryScreenshotWidget(
        child: widgets.Text('Lorem ipsum', textDirection: TextDirection.ltr),
      ),
    );

    final context = sentryScreenshotWidgetGlobalKey.currentContext;
    final renderObject = context?.findRenderObject() as RenderRepaintBoundary;
    final image = await renderObject.toImage();
    final size = renderObject.size;
    print('Render object size: ${size.width}x${size.height}');
    print('Image size: ${image.width}x${image.height}');

    (await asyncBenchmark('RenderRepaintBoundary.toImage()', () async {
      final image = await renderObject.toImage();
      // Dispose should have very little impact and ensures we don't run out of memory
      image.dispose();
    }))
        .report();

    for (final format in ImageByteFormat.values) {
      (await asyncBenchmark('Image.toByteData(${format.name})',
              () => image.toByteData(format: format)))
          .report();
    }

    syncBenchmark('Image to Picture', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());
      recorder.endRecording().dispose();
    }).report();

    (await PictureToImageBenchmark(image).measure()).report();

    CanvasObscureBenchmark(image).measure().report();

    image.dispose();
  });
}

class PictureToImageBenchmark extends AsyncBenchmark {
  late final Picture picture;
  final int width;
  final int height;

  PictureToImageBenchmark(Image source)
      : width = source.width,
        height = source.height,
        super('Picture.toImage()') {
    final recorder = PictureRecorder();
    Canvas(recorder).drawImage(source, Offset.zero, Paint());
    picture = recorder.endRecording();
  }

  @override
  Future<void> run() async {
    final image = await picture.toImage(width, height);

    // Dispose should have very little impact and ensures we don't run out of memory
    image.dispose();
  }
}

class CanvasObscureBenchmark extends SyncBenchmark {
  static const _count = 100;
  late final Canvas _canvas;
  late final List<WidgetFilterItem> _items;
  late final double _pixelRatio;

  CanvasObscureBenchmark(Image source) : super('Canvas.drawRect() x $_count') {
    _canvas = Canvas(PictureRecorder());
    _canvas.drawImage(source, Offset.zero, Paint());
    _pixelRatio = Random().nextDouble();

    // generate a list of random rectangles to mask
    _items = List.generate(
      _count,
      (index) {
        final left = source.width * Random().nextDouble();
        final top = source.height * Random().nextDouble();
        final width = (source.width - left) * Random().nextDouble();
        final height = (source.height - top) * Random().nextDouble();
        return WidgetFilterItem(Color(Random().nextInt(0xFFFFFFFF)),
            Rect.fromLTWH(left, top, width, height));
      },
      growable: true, // it would be growable in the actual code too
    );
  }

  @override
  void run() {
    // Same code as recorder.dart _Capture._obscureWidgets()
    final paint = Paint()..style = PaintingStyle.fill;
    for (var item in _items) {
      paint.color = item.color;
      final source = item.bounds;
      final scaled = Rect.fromLTRB(
          source.left * _pixelRatio,
          source.top * _pixelRatio,
          source.right * _pixelRatio,
          source.bottom * _pixelRatio);
      _canvas.drawRect(scaled, paint);
    }
  }
}
