// Borrowed from https://api.dart.dev/stable/2.17.6/dart-core/Object/hash.html
// Since Object.hash(a, b) is only available from Dart 2.14

// A per-isolate seed for hash code computations.
final int _hashSeed = identityHashCode(Object);

int _combine(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int hash2(int v1, int v2) {
  int hash = _hashSeed;
  hash = _combine(hash, v1);
  hash = _combine(hash, v2);
  return _finish(hash);
}

int _finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
