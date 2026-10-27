// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/screen_capture/widget_filter.dart';

import '../mocks.dart';
import 'test_widget.dart';

// Note: these tests predate existance of `SentryMaskingConfig` which now
// takes care of the decision making whether something is masked or not.
// We'll keep these tests although they're not unit-tests anymore.
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final rootBundle = TestAssetBundle();
  final otherBundle = TestAssetBundle();
  final capturedLogs = <MockLogItem>[];
  final colorScheme = WidgetFilterColorScheme(
    defaultMask: Colors.white,
    defaultTextMask: Colors.green,
    background: Colors.red,
  );

  setUp(() {
    capturedLogs.clear();
    SentryInternalLogger.configure(
      isEnabled: true,
      minLevel: SentryLevel.debug,
      logOutput:
          ({
            required String name,
            required SentryLevel level,
            required String message,
            Object? error,
            StackTrace? stackTrace,
          }) {
            capturedLogs.add(
              MockLogItem(
                level,
                message,
                exception: error,
                stackTrace: stackTrace,
              ),
            );
          },
    );
  });

  tearDown(() {
    SentryInternalLogger.configure(isEnabled: false);
  });

  final createSut =
      ({
        bool redactImages = false,
        bool redactText = false,
        RuntimeChecker? runtimeChecker,
      }) {
        final privacyOptions = SentryPrivacyOptions()
          ..maskAllImages = redactImages
          ..maskAllText = redactText;
        capturedLogs.clear();
        final maskingConfig = privacyOptions.buildMaskingConfig(
          runtimeChecker ?? RuntimeChecker(),
        );
        return WidgetFilter(maskingConfig);
      };

  boundsRect(WidgetFilterItem item) =>
      '${item.bounds.width.floor()}x${item.bounds.height.floor()}';

  group('redact text', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 7);
    });

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactText: false);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen', (
      tester,
    ) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        bounds: Rect.fromLTRB(0, 0, 100, 100),
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactText: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 7);
      expect(
        sut.items.map(boundsRect),
        unorderedEquals([
          '624x48',
          '169x20',
          '800x192',
          '800x24',
          '800x24',
          '50x20',
          '144x16',
        ]),
      );
    });
  });

  group('redact images', () {
    testWidgets('redacts the correct number of elements', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 3);
    });

    // Note: we cannot currently test actual asset images without either:
    // - introducing assets to the package because those wouldn't get tree-shaken in final user apps (https://github.com/flutter/flutter/issues/64106)
    // - using a mock asset bundle implementation, because the image widget loads AssetManifest.bin first and we don't have a way to mock that (https://github.com/flutter/flutter/issues/126860)
    // Therefore we only check the function that actually decides whether the image is a built-in asset image.
    for (var newAssetImage in [AssetImage.new, ExactAssetImage.new]) {
      testWidgets(
        'recognizes ${newAssetImage('').runtimeType} from the root bundle',
        (tester) async {
          expect(
            WidgetFilter.isBuiltInAssetImage(newAssetImage(''), rootBundle),
            isTrue,
          );
          expect(
            WidgetFilter.isBuiltInAssetImage(
              newAssetImage('', bundle: rootBundle),
              rootBundle,
            ),
            isTrue,
          );
          expect(
            WidgetFilter.isBuiltInAssetImage(
              newAssetImage('', bundle: otherBundle),
              rootBundle,
            ),
            isFalse,
          );
          expect(
            WidgetFilter.isBuiltInAssetImage(
              newAssetImage('', bundle: SentryAssetBundle(bundle: rootBundle)),
              rootBundle,
            ),
            isTrue,
          );
          expect(
            WidgetFilter.isBuiltInAssetImage(
              newAssetImage('', bundle: SentryAssetBundle(bundle: otherBundle)),
              rootBundle,
            ),
            isFalse,
          );
        },
      );
    }

    testWidgets('does not redact text when disabled', (tester) async {
      final sut = createSut(redactImages: false);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 0);
    });

    testWidgets('does not redact elements that are outside the screen', (
      tester,
    ) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        bounds: Rect.fromLTRB(0, 0, 500, 100),
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 1);
    });

    testWidgets('correctly determines sizes', (tester) async {
      final sut = createSut(redactImages: true);
      final element = await pumpTestElement(tester);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.length, 3);
      expect(boundsRect(sut.items[0]), '1x1');
      expect(boundsRect(sut.items[1]), '1x1');
      expect(boundsRect(sut.items[2]), '50x20');
    });
  });

  testWidgets('respects $SentryMask', (tester) async {
    final sut = createSut(redactText: false, redactImages: false);
    final element = await pumpTestElement(
      tester,
      children: [
        SentryMask(Padding(padding: EdgeInsets.all(100), child: Text('foo'))),
      ],
    );
    sut.obscure(
      context: element,
      root: element.renderObject as RenderRepaintBoundary,
      colorScheme: colorScheme,
    );
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '344x248');
  });

  testWidgets('respects $SentryUnmask', (tester) async {
    final sut = createSut(redactText: true, redactImages: true);
    final element = await pumpTestElement(
      tester,
      children: [
        SentryUnmask(Text('foo')),
        SentryUnmask(newImage()),
        SentryUnmask(SentryMask(Text('foo'))),
      ],
    );
    sut.obscure(
      context: element,
      root: element.renderObject as RenderRepaintBoundary,
      colorScheme: colorScheme,
    );
    expect(sut.items, isEmpty);
  });

  testWidgets('obscureElementOrParent', (tester) async {
    final sut = createSut(redactText: true);
    final element = await pumpTestElement(
      tester,
      children: [Padding(padding: EdgeInsets.all(100), child: Text('foo'))],
    );
    sut.obscure(
      context: element,
      root: element.renderObject as RenderRepaintBoundary,
      colorScheme: colorScheme,
    );
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '144x48');
    sut.throwInObscure = true;
    sut.obscure(
      context: element,
      root: element.renderObject as RenderRepaintBoundary,
      colorScheme: colorScheme,
    );
    expect(sut.items.length, 1);
    expect(boundsRect(sut.items[0]), '344x248');
  });

  group('warning on sensitive widgets', () {
    assert(MockRuntimeCheckerBuildMode.values.length == 3);
    for (final buildMode in MockRuntimeCheckerBuildMode.values) {
      testWidgets(buildMode.name, (tester) async {
        final sut = createSut(
          redactText: true,
          runtimeChecker: MockRuntimeChecker(buildMode: buildMode),
        );
        final element = await pumpTestElement(
          tester,
          children: [CustomPasswordWidget()],
        );
        sut.obscure(
          context: element,
          root: element.renderObject as RenderRepaintBoundary,
          colorScheme: colorScheme,
        );
        final logMessages = capturedLogs
            .where((item) => item.level == SentryLevel.warning)
            .map((item) => item.message)
            .toList();

        if (buildMode == MockRuntimeCheckerBuildMode.debug) {
          expect(
            logMessages,
            anyElement(
              contains(
                'name matches widgets that should usually be masked because they may contain sensitive data',
              ),
            ),
          );
        } else {
          expect(logMessages, isEmpty);
        }
      });
    }
  });

  group('under a $SnapshotWidget painter transform', () {
    Future<Element> pumpScaled(
      WidgetTester tester, {
      required List<double> scales,
    }) async {
      Widget child = const Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: SentryMask(SizedBox(width: 100, height: 40)),
          ),
        ],
      );
      for (final scale in scales.reversed) {
        child = SnapshotWidget(
          controller: SnapshotController(),
          painter: _CenterScalePainter(scale),
          child: child,
        );
      }
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(width: 400, height: 400, child: child),
            ),
          ),
        ),
      );
      return tester.element(find.byType(RepaintBoundary).first);
    }

    testWidgets('masks the scaled position', (tester) async {
      final sut = createSut();
      final element = await pumpScaled(tester, scales: [0.5]);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.map((item) => item.bounds), [
        const Rect.fromLTWH(100, 100, 50, 20),
      ]);
    });

    testWidgets('composes nested transforms', (tester) async {
      final sut = createSut();
      final element = await pumpScaled(tester, scales: [0.5, 0.5]);
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      expect(sut.items.map((item) => item.bounds), [
        const Rect.fromLTWH(150, 150, 25, 10),
      ]);
    });
  });

  group('during a $ZoomPageTransitionsBuilder push', () {
    const outgoingKey = ValueKey('outgoing');
    const incomingKey = ValueKey('incoming');
    const outgoingPageKey = ValueKey('outgoing page');
    const incomingPageKey = ValueKey('incoming page');

    Widget page(Key pageKey, Key key, Offset position) => ColoredBox(
      key: pageKey,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned(
            left: position.dx,
            top: position.dy,
            child: SentryMask(SizedBox(key: key, width: 100, height: 40)),
          ),
        ],
      ),
    );

    /// Pushes a page and stops partway through the zoom.
    Future<Element> pumpMidZoom(
      WidgetTester tester, {
      required bool allowSnapshotting,
    }) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final builder = ZoomPageTransitionsBuilder(
        allowSnapshotting: allowSnapshotting,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            // Pumping a different builder must not lerp from the previous.
            themeAnimationDuration: Duration.zero,
            theme: ThemeData(
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  for (final platform in TargetPlatform.values)
                    platform: builder,
                },
              ),
            ),
            home: page(outgoingPageKey, outgoingKey, const Offset(20, 60)),
          ),
        ),
      );
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                page(incomingPageKey, incomingKey, const Offset(200, 300)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return tester.element(find.byType(RepaintBoundary).first);
    }

    WidgetFilter obscure(Element element) {
      final sut = createSut();
      sut.obscure(
        context: element,
        root: element.renderObject as RenderRepaintBoundary,
        colorScheme: colorScheme,
      );
      return sut;
    }

    List<Rect> boundsOf(Iterable<WidgetFilterItem> items) =>
        items.map((item) => item.bounds).toList();

    /// Where [key]'s box is actually painted relative to [root], read from
    /// the layer tree. Only valid without snapshotting, which paints the
    /// page into a detached image instead.
    Rect paintedRect(WidgetTester tester, Key key, RenderObject root) {
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      var boundary = box as RenderObject;
      while (!boundary.isRepaintBoundary) {
        boundary = boundary.parent!;
      }
      final layers = <ContainerLayer>[];
      for (
        ContainerLayer? layer = boundary.debugLayer as ContainerLayer;
        layer != null && layer != root.debugLayer;
        layer = layer.parent
      ) {
        layers.add(layer);
      }
      final transform = Matrix4.identity();
      for (final layer in layers.reversed) {
        layer.applyTransform(layer.firstChild, transform);
      }
      transform.multiply(box.getTransformTo(boundary));
      return MatrixUtils.transformRect(transform, box.paintBounds);
    }

    testWidgets('masks both pages where they are painted', (tester) async {
      final element = await pumpMidZoom(tester, allowSnapshotting: false);
      final root = element.renderObject!;
      final incoming = paintedRect(tester, incomingKey, root);
      final outgoing = paintedRect(tester, outgoingKey, root);
      // Guard against a vacuous pass: the zoom must be mid-scale.
      expect(incoming.size, isNot(const Size(100, 40)));
      expect(outgoing.size, isNot(const Size(100, 40)));

      expect(
        boundsOf(obscure(element).items),
        unorderedEquals([
          rectMoreOrLessEquals(incoming),
          rectMoreOrLessEquals(outgoing),
        ]),
      );
    });

    testWidgets('without snapshotting reports no frozen snapshot', (
      tester,
    ) async {
      final sut = obscure(await pumpMidZoom(tester, allowSnapshotting: false));

      expect(sut.hasFrozenSnapshot, isFalse);
    });

    group('with snapshotting', () {
      testWidgets('reports a frozen snapshot', (tester) async {
        final sut = obscure(await pumpMidZoom(tester, allowSnapshotting: true));

        expect(sut.hasFrozenSnapshot, isTrue);
      });

      testWidgets('covers both pages with the background', (tester) async {
        // The snapshots are frozen images, so content that moves under them
        // can't be tracked: each page is covered whole instead.
        final element = await pumpMidZoom(tester, allowSnapshotting: false);
        final root = element.renderObject!;
        final incoming = paintedRect(tester, incomingPageKey, root);
        final outgoing = paintedRect(tester, outgoingPageKey, root);

        final sut = obscure(await pumpMidZoom(tester, allowSnapshotting: true));

        expect(
          boundsOf(
            sut.items.where((item) => item.color == colorScheme.background),
          ),
          unorderedEquals([
            rectMoreOrLessEquals(incoming),
            rectMoreOrLessEquals(outgoing),
          ]),
        );
      });

      testWidgets('masks both pages on top of the covers', (tester) async {
        final withoutSnapshots = boundsOf(
          obscure(await pumpMidZoom(tester, allowSnapshotting: false)).items,
        );

        final items = obscure(
          await pumpMidZoom(tester, allowSnapshotting: true),
        ).items;
        final firstMask = items.indexWhere(
          (item) => item.color != colorScheme.background,
        );

        expect(
          items.take(firstMask).map((item) => item.color),
          everyElement(colorScheme.background),
        );
        expect(boundsOf(items.skip(firstMask)), [
          for (final rect in withoutSnapshots) rectMoreOrLessEquals(rect),
        ]);
      });
    });
  });
}

/// Scales the child by [scale] around the center while painting, like
/// Flutter's zoom page transition does.
class _CenterScalePainter extends SnapshotPainter {
  _CenterScalePainter(this.scale);

  final double scale;

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    final center = size.center(Offset.zero);
    final transform = Matrix4.translationValues(center.dx, center.dy, 0)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    context.pushTransform(true, offset, transform, painter);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {}

  @override
  bool shouldRepaint(covariant _CenterScalePainter oldPainter) =>
      oldPainter.scale != scale;
}

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}

class CustomPasswordWidget extends Column {
  const CustomPasswordWidget({super.key});
}
