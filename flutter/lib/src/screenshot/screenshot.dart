import 'dart:async';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

@internal
class Screenshot {
  final Image _image;
  final DateTime timestamp;
  final Flow flow;
  Future<ByteData>? _rawData;
  Future<ByteData>? _pngData;

  Screenshot(this._image, this.timestamp, this.flow);
  Screenshot._cloned(
      this._image, this.timestamp, this.flow, this._rawData, this._pngData);

  int get width => _image.width;
  int get height => _image.height;

  Future<ByteData> get rawData {
    _rawData ??= _encode(ImageByteFormat.rawUnmodified);
    return _rawData!;
  }

  Future<ByteData> get pngData {
    _pngData ??= _encode(ImageByteFormat.png);
    return _pngData!;
  }

  Future<ByteData> _encode(ImageByteFormat format) async {
    Timeline.startSync('Sentry::screenshotTo${format.name}', flow: flow);
    final result =
        await _image.toByteData(format: format).then((data) => data!);
    Timeline.finishSync();
    return result;
  }

  Future<bool> hasSameImageAs(Screenshot other) async {
    if (other.width != width || other.height != height) {
      return false;
    }

    return listEquals(await rawData, await other.rawData);
  }

  Screenshot clone() {
    assert(!_image.debugDisposed);
    return Screenshot._cloned(
        _image.clone(), timestamp, flow, _rawData, _pngData);
  }

  void dispose() => _image.dispose();

  /// Efficiently compares two memory regions for data equality..
  @visibleForTesting
  static bool listEquals(ByteData dataA, ByteData dataB) {
    if (identical(dataA, dataB)) {
      return true;
    }
    if (dataA.lengthInBytes != dataB.lengthInBytes) {
      return false;
    }

    /// Ideally, we would use memcmp with Uint8List.address but that's only
    /// available since Dart 3.5.0. The relevant code is commented out below and
    /// Should be used once we can bump the Dart SDK in the next major version.
    /// For now, the best we can do is compare by chunks of 8 bytes.
    // return 0 == memcmp(dataA.address, dataB.address, dataA.lengthInBytes);

    final numWords = dataA.lengthInBytes ~/ 8;
    final wordsA = dataA.buffer.asUint64List(0, numWords);
    final wordsB = dataB.buffer.asUint64List(0, numWords);

    for (var i = 0; i < wordsA.length; i++) {
      if (wordsA[i] != wordsB[i]) {
        return false;
      }
    }

    // Compare any remaining bytes.
    final bytesA = dataA.buffer.asUint8List(wordsA.lengthInBytes);
    final bytesB = dataB.buffer.asUint8List(wordsA.lengthInBytes);
    for (var i = 0; i < bytesA.lengthInBytes; i++) {
      if (bytesA[i] != bytesB[i]) {
        return false;
      }
    }

    return true;
  }
}

// /// Compares the first num bytes of the block of memory pointed by ptr1 to the
// /// first num bytes pointed by ptr2, returning zero if they all match or a value
// ///  different from zero representing which is greater if they do not.
// @Native<Int32 Function(Pointer, Pointer, Int32)>(symbol: 'memcmp', isLeaf: true)
// external int memcmp(Pointer<Uint8> ptr1, Pointer<Uint8> ptr2, int len);
