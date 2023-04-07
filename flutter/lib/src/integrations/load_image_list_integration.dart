import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// Loads the native debug image list for stack trace symbolication.
class LoadImageListIntegration extends Integration<SentryFlutterOptions> {
  final MethodChannel _channel;

  LoadImageListIntegration(this._channel);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadImageListIntegrationEventProcessor(_channel, options),
    );

    options.sdk.addIntegration('loadImageListIntegration');
  }
}

extension _NeedsSymbolication on SentryEvent {
  bool needsSymbolication() {
    if (this is SentryTransaction) {
      return false;
    }
    if (exceptions?.isNotEmpty == false) {
      return false;
    }
    final frames = exceptions?.first.stackTrace?.frames;
    if (frames == null) {
      return false;
    }
    return frames.any((frame) => 'native' == frame.platform);
  }
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._channel, this._options);

  final MethodChannel _channel;
  final SentryFlutterOptions _options;

  @override
  Future<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (event.needsSymbolication()) {
      try {
        // we call on every event because the loaded image list is cached
        // and it could be changed on the Native side.
        final loadImageList = await _channel.invokeMethod('loadImageList');
        final imageList = List<Map<dynamic, dynamic>>.from(
          loadImageList is List ? loadImageList : [],
        );
        return copyWithDebugImages(event, imageList);
      } catch (exception, stackTrace) {
        _options.logger(
          SentryLevel.error,
          'loadImageList failed',
          exception: exception,
          stackTrace: stackTrace,
        );
      }
    }

    return event;
  }

  static SentryEvent copyWithDebugImages(
      SentryEvent event, List<Object?> imageList) {
    if (imageList.isEmpty) {
      return event;
    }

    final newDebugImages = <DebugImage>[];
    for (final obj in imageList) {
      final jsonMap = Map<String, dynamic>.from(obj as Map<dynamic, dynamic>);
      final image = DebugImage.fromJson(jsonMap);
      newDebugImages.add(image);
    }

    return event.copyWith(debugMeta: DebugMeta(images: newDebugImages));
  }
}
