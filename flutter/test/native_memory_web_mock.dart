import 'dart:math';
import 'dart:typed_data';

// This is just a mock so `flutter test --platform chrome` works.
// See https://github.com/flutter/flutter/issues/160675
class NativeMemory {
  final Pointer<Uint8> pointer;
  final int length;

  const NativeMemory._(this.pointer, this.length);

  factory NativeMemory.fromUint8List(Uint8List source) {
    return NativeMemory._(Pointer<Uint8>._store(source), source.length);
  }

  factory NativeMemory.fromJson(Map<dynamic, dynamic> json) {
    return NativeMemory._(
        Pointer<Uint8>._load(json['address'] as int), json['length'] as int);
  }

  void free() {}

  Uint8List asTypedList() => _memory[pointer.address]!;

  Map<String, int> toJson() => {
        'address': pointer.address,
        'length': length,
      };
}

class Pointer<T> {
  final int address;

  const Pointer(this.address);

  factory Pointer._store(Uint8List data) {
    final address = Random().nextInt(999999);
    _memory[address] = data;
    return Pointer(address);
  }

  factory Pointer._load(int address) {
    return Pointer(address);
  }

  /// Equality for Pointers only depends on their address.
  @override
  bool operator ==(Object other) {
    if (other is! Pointer) return false;
    return address == other.address;
  }

  /// The hash code for a Pointer only depends on its address.
  @override
  int get hashCode => address.hashCode;
}

class Uint8 {}

final _memory = <int, Uint8List>{};
