import 'dart:async';

import 'package:file/local.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';
import 'package:file/file.dart';
import '../native/sentry_native_binding.dart';
import '../sentry_flutter_options.dart';

/// Loads the native debug image list for stack trace symbolication.
class LoadImageListIntegration extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;

  LoadImageListIntegration(this._native);

  @override
  void call(Hub hub, SentryFlutterOptions options) {
    options.addEventProcessor(
      _LoadImageListIntegrationEventProcessor(options, _native),
    );

    options.sdk.addIntegration('loadImageListIntegration');
  }
}

extension on SentryEvent {
  SentryStackTrace? _getStacktrace() {
    var stackTrace =
        exceptions?.firstWhereOrNull((e) => e.stackTrace != null)?.stackTrace;
    stackTrace ??=
        threads?.firstWhereOrNull((t) => t.stacktrace != null)?.stacktrace;
    return stackTrace;
  }
}

class _LoadImageListIntegrationEventProcessor implements EventProcessor {
  _LoadImageListIntegrationEventProcessor(this._options, this._native);

  final SentryFlutterOptions _options;
  final SentryNativeBinding _native;
  DebugImage? _appDebugImage;

  @visibleForTesting
  FileSystem fs = LocalFileSystem();

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final stackTrace = event._getStacktrace();

    // if the stacktrace has native frames, we load native debug images.
    if (stackTrace != null &&
        stackTrace.frames.any((frame) => 'native' == frame.platform)) {
      final images = await _native.loadDebugImages();
      if (images != null) {
        // On windows, we need to add the ELF debug image of the AOT code.
        // See https://github.com/flutter/flutter/issues/154840
        if (_options.platformChecker.platform.isWindows) {
          _appDebugImage ??= await _getAppDebugImage(stackTrace, images);
          if (_appDebugImage != null) {
            images.add(_appDebugImage!);
          }
        }
        return event.copyWith(debugMeta: DebugMeta(images: images));
      }
    }

    return event;
  }

  Future<DebugImage?> _getAppDebugImage(
      SentryStackTrace stackTrace, Iterable<DebugImage> nativeImages) async {
    // ignore: invalid_use_of_internal_member
    final buildId = stackTrace.nativeBuildId;
    // ignore: invalid_use_of_internal_member
    final imageAddr = stackTrace.nativeImageBaseAddr;

    if (buildId == null || imageAddr == null) {
      return null;
    }

    final exePath = nativeImages
        .firstWhereOrNull(
            (image) => image.codeFile?.toLowerCase().endsWith('.exe') ?? false)
        ?.codeFile;
    if (exePath == null) {
      _options.logger(
          SentryLevel.debug,
          "Couldn't add AOT ELF image for server-side symbolication because the "
          "app executable is not among the debug images reported by native.");
      return null;
    }

    final appSoFile =
        fs.file(exePath).parent.childDirectory('data').childFile('app.so');
    if (!await appSoFile.exists()) {
      _options.logger(SentryLevel.debug,
          "Couldn't add AOT ELF image because ${appSoFile.path} doesn't exist.");
      return null;
    }

    final stat = await appSoFile.stat();
    return DebugImage(
      type: 'elf',
      imageAddr: imageAddr,
      imageSize: stat.size,
      codeFile: appSoFile.path,
      codeId: buildId,
    );
  }
}
