import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:sentry/sentry.dart';

final _gloablKey = GlobalKey(debugLabel: 'sentry_screenshot');

class SentryScreenshot extends StatelessWidget {
  const SentryScreenshot({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _gloablKey,
      child: child,
    );
  }
}

class ScreenshotAttachment extends SentryAttachment {
  ScreenshotAttachment()
      : super.fromLoader(
          filename: 'screenshot.png',
          contentType: 'image/png',
          loader: _createScreenshot,
        );

  static FutureOr<Uint8List> _createScreenshot() async {
    final _completer = Completer<Uint8List?>();
    final instance = WidgetsBinding.instance;
    if (instance == null) {
      _completer.complete(null);
      return await _completer.future ?? Uint8List.fromList([]);
    }
    instance.addPostFrameCallback((timeStamp) async {
      final renderObject = _gloablKey.currentContext?.findRenderObject();

      if (renderObject is RenderRepaintBoundary) {
        final image = await renderObject.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        _completer.complete(bytes?.buffer.asUint8List());
      } else {
        _completer.complete(null);
      }
    });
    return await _completer.future ?? Uint8List.fromList([]);
  }
}
