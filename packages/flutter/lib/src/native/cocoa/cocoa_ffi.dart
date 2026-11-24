import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../sentry_safe_method_channel.dart';
import 'binding.dart';

typedef _AddBreadcrumbNative = Void Function(Pointer<Uint8>, Size);
typedef _AddBreadcrumbDart = void Function(Pointer<Uint8>, int);

/// Direct FFI calls into the Cocoa plugin.
///
/// The native side hands over the address of a static
/// `SentryFlutterFfiEntryPoints` struct (see `SentryFlutterFFI.h`) via the
/// `ffiEntryPoints` method-channel call. No symbol is looked up by name, so
/// release-build symbol stripping of the statically linked plugin cannot
/// break these calls.
///
/// Calls are synchronous and must happen on the main isolate.
@internal
class CocoaFfi {
  final _AddBreadcrumbDart _addBreadcrumb;

  CocoaFfi._(this._addBreadcrumb);

  /// Returns `null` when the native side provides no usable entry points;
  /// callers then fall back to the method channel.
  static Future<CocoaFfi?> load(SentrySafeMethodChannel channel) async {
    final address = await channel.invokeMethod<int>('ffiEntryPoints');
    if (address == null || address == 0) return null;
    final entryPoints = Pointer<SentryFlutterFfiEntryPoints>.fromAddress(
      address,
    ).ref;
    final addBreadcrumb = entryPoints.addBreadcrumb;
    if (addBreadcrumb == nullptr) return null;
    return CocoaFfi._(
      addBreadcrumb.cast<NativeFunction<_AddBreadcrumbNative>>().asFunction(),
    );
  }

  /// Adds a breadcrumb from its already-normalized JSON representation.
  void addBreadcrumb(Map<String, dynamic> normalizedBreadcrumbJson) {
    final bytes = utf8.encode(jsonEncode(normalizedBreadcrumbJson));
    final buffer = malloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      _addBreadcrumb(buffer, bytes.length);
    } finally {
      malloc.free(buffer);
    }
  }
}
