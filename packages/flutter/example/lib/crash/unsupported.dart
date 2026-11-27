Never _unsupported() {
  throw UnsupportedError('Native crashes are not supported on this platform.');
}

void abort() => _unsupported();

void failFast() => _unsupported();
