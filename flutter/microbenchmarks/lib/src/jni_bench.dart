import 'dart:ffi';
import 'dart:math';

import 'package:jni/jni.dart';
import 'package:benchmarking/benchmarking.dart';
import 'package:flutter/foundation.dart';

Future<void> execute() async {
  final worksets = [
    _WorkSet(10 * 1000),
    _WorkSet(1000 * 1000),
    _WorkSet(10 * 1000 * 1000),
  ];

  // For baseline
  syncBenchmark('JByteBuffer.release()', () {
    JByteBuffer.allocateDirect(1).release();
  }).report();

  for (var workset in worksets) {
    syncBenchmark('JByteBuffer.fromList(${workset.size})', () {
      final jBuffer = JByteBuffer.fromList(workset.data);
      jBuffer.release();
    }).report();

    syncBenchmark('JByteBuffer.allocatedDirect(${workset.size})', () {
      final jBuffer = JByteBuffer.allocateDirect(workset.size);
      jBuffer.release();
    }).report();

    syncBenchmark('JByteBuffer.allocatedDirect(${workset.size}) + memcpy', () {
      final jBuffer = JByteBuffer.allocateDirect(workset.size);
      final jData = jBuffer._asUint8ListUnsafe();
      memcpy(jData.address, workset.data.address, workset.size);
      jBuffer.release();
    }).report();
  }
}

class _WorkSet {
  static final rand = Random();
  final int size;
  late final Uint8List data;

  _WorkSet(this.size) {
    // Randomized size prevents loop optimizations of constant sized loops. Just in case...

    data = Uint8List.fromList(
        List.generate(size, (_) => rand.nextInt(size) % 256));
  }
}

// Copied over from package:jni due to visibility
extension on JByteBuffer {
  Uint8List _asUint8ListUnsafe() {
    _ensureIsDirect();
    final address = _directBufferAddress();
    final capacity = _directBufferCapacity();
    return address.cast<Uint8>().asTypedList(capacity);
  }

  Pointer<Void> _directBufferAddress() {
    final address = Jni.env.GetDirectBufferAddress(reference.pointer);
    if (address == nullptr) {
      throw StateError(
        'The memory region is undefined or '
        'direct buffer access is not supported by this JVM.',
      );
    }
    return address;
  }

  int _directBufferCapacity() {
    final capacity = Jni.env.GetDirectBufferCapacity(reference.pointer);
    if (capacity == -1) {
      throw StateError(
        'The object is an unaligned view buffer and the processor '
        'architecture does not support unaligned access.',
      );
    }
    return capacity;
  }

  void _ensureIsDirect() {
    if (!isDirect) {
      throw StateError(
        'The buffer must be created with `JByteBuffer.allocateDirect`.',
      );
    }
  }
}

/// void* memcpy( void* dest, const void* src, std::size_t count );
@Native<Void Function(Pointer, Pointer, Int32)>(symbol: 'memcpy', isLeaf: true)
external void memcpy(Pointer<Uint8> dest, Pointer<Uint8> src, int count);
