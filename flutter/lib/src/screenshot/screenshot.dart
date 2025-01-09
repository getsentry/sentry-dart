import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:ui';
// ignore: unnecessary_import // backcompatibility for Flutter < 3.3
import 'dart:typed_data';

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
    _rawData ??= _image
        .toByteData(format: ImageByteFormat.rawUnmodified)
        .then((data) => data!);
    return _rawData!;
  }

  Future<ByteData> get pngData {
    _pngData ??=
        _image.toByteData(format: ImageByteFormat.png).then((data) => data!);
    return _pngData!;
  }

  Future<bool> hasSameImageAs(Screenshot other) async {
    if (other.width != width || other.height != height) {
      return false;
    }

    final thisData = await rawData;
    final otherData = await other.rawData;
    if (thisData.lengthInBytes != otherData.lengthInBytes) {
      return false;
    }
    if (identical(thisData, otherData)) {
      return true;
    }

    // Note: listEquals() is slow because it compares each byte pair.
    // Ideally, we would use memcmp with Uint8List.address but that's only
    // available since Dart 3.5.0.
    // For now, the best we can do is compare by chunks
    var pos = 0;
    while (pos + 8 < thisData.lengthInBytes) {
      if (thisData.getInt64(pos) != otherData.getInt64(pos)) {
        return false;
      }
      pos += 8;
    }
    while (pos < thisData.lengthInBytes) {
      if (thisData.getUint8(pos) != otherData.getUint8(pos)) {
        return false;
      }
      pos++;
    }
    return true;
  }

  Screenshot clone() {
    assert(!_image.debugDisposed);
    return Screenshot._cloned(
        _image.clone(), timestamp, flow, _rawData, _pngData);
  }

  void dispose() => _image.dispose();
}
