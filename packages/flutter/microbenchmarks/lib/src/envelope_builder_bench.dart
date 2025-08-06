import 'dart:typed_data';
import 'dart:math';

const _minIterations = 50;
const _maxIterations = 1000;

Future<void> execute() async {
  print('Envelope Builder Benchmark');
  print('==========================');
  print('Comparing legacy List<int> vs BytesBuilder approaches\n');

  // Test with different envelope sizes
  final sizes = [
    (1024, '1 KB'),
    (10 * 1024, '10 KB'),
    (100 * 1024, '100 KB'),
    (1024 * 1024, '1 MB'),
    (5 * 1024 * 1024, '5 MB'),
  ];

  for (final (size, label) in sizes) {
    print('Envelope size: $label');
    print('-' * 40);

    // Use adaptive iteration count based on data size
    final iterations = _getIterationCount(size);
    print('Running $iterations iterations...');

    // Create mock envelope data
    final mockData = _generateMockEnvelopeData(size);

    // Benchmark legacy approach
    final legacyResults = await _benchmarkLegacyApproach(mockData, iterations);
    final legacyAvg =
        legacyResults.reduce((a, b) => a + b) / legacyResults.length;
    final legacyMin = legacyResults.reduce(min);
    final legacyMax = legacyResults.reduce(max);

    // Benchmark new approach
    final newResults = await _benchmarkNewApproach(mockData, iterations);
    final newAvg = newResults.reduce((a, b) => a + b) / newResults.length;
    final newMin = newResults.reduce(min);
    final newMax = newResults.reduce(max);

    // Calculate improvement
    final improvement =
        ((legacyAvg - newAvg) / legacyAvg * 100).toStringAsFixed(1);
    final speedup = (legacyAvg / newAvg).toStringAsFixed(2);

    print('Legacy approach (List<int> + addAll):');
    print('  Average: ${_formatMicroseconds(legacyAvg)}');
    print('  Min: ${_formatMicroseconds(legacyMin)}');
    print('  Max: ${_formatMicroseconds(legacyMax)}');

    print('New approach (BytesBuilder):');
    print('  Average: ${_formatMicroseconds(newAvg)}');
    print('  Min: ${_formatMicroseconds(newMin)}');
    print('  Max: ${_formatMicroseconds(newMax)}');

    print('Performance improvement: $improvement% (${speedup}x faster)');
    print('');
  }
}

// Adaptive iteration count to avoid memory pressure and hanging
int _getIterationCount(int dataSize) {
  if (dataSize <= 10 * 1024) {
    return _maxIterations; // 1K iterations for <= 10KB
  } else if (dataSize <= 100 * 1024) {
    return _maxIterations ~/ 2; // 500 iterations for <= 100KB
  } else if (dataSize <= 1024 * 1024) {
    return _maxIterations ~/ 5; // 200 iterations for <= 1MB
  } else {
    return _minIterations; // 50 iterations for > 1MB
  }
}

// Generate mock envelope data chunks to simulate streaming
List<List<int>> _generateMockEnvelopeData(int totalSize) {
  final chunks = <List<int>>[];
  final random = Random(42); // Fixed seed for reproducibility

  // Simulate realistic chunk sizes (similar to how envelope streams work)
  final chunkSizes = [64, 128, 256, 512, 1024];
  var remaining = totalSize;

  while (remaining > 0) {
    final chunkSize = chunkSizes[random.nextInt(chunkSizes.length)];
    final actualSize = remaining < chunkSize ? remaining : chunkSize;

    // Create chunk with random data
    final chunk = List<int>.generate(actualSize, (_) => random.nextInt(256));
    chunks.add(chunk);
    remaining -= actualSize;
  }

  return chunks;
}

Future<List<double>> _benchmarkLegacyApproach(
    List<List<int>> chunks, int iterations) async {
  final results = <double>[];

  // Reduced warmup for large data
  final warmupIterations = min(20, iterations ~/ 5);

  // Warmup
  for (var i = 0; i < warmupIterations; i++) {
    _runLegacyApproach(chunks);
  }

  // Actual benchmark
  for (var i = 0; i < iterations; i++) {
    final stopwatch = Stopwatch()..start();
    _runLegacyApproach(chunks);
    stopwatch.stop();
    results.add(stopwatch.elapsedMicroseconds.toDouble());
  }

  return results;
}

Future<List<double>> _benchmarkNewApproach(
    List<List<int>> chunks, int iterations) async {
  final results = <double>[];

  // Reduced warmup for large data
  final warmupIterations = min(20, iterations ~/ 5);

  // Warmup
  for (var i = 0; i < warmupIterations; i++) {
    _runNewApproach(chunks);
  }

  // Actual benchmark
  for (var i = 0; i < iterations; i++) {
    final stopwatch = Stopwatch()..start();
    _runNewApproach(chunks);
    stopwatch.stop();
    results.add(stopwatch.elapsedMicroseconds.toDouble());
  }

  return results;
}

Uint8List _runLegacyApproach(List<List<int>> chunks) {
  final envelopeData = <int>[];
  for (final chunk in chunks) {
    envelopeData.addAll(chunk);
  }
  return Uint8List.fromList(envelopeData);
}

Uint8List _runNewApproach(List<List<int>> chunks) {
  final builder = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

String _formatMicroseconds(double microseconds) {
  if (microseconds < 1000) {
    return '${microseconds.toStringAsFixed(1)} μs';
  } else if (microseconds < 1000000) {
    return '${(microseconds / 1000).toStringAsFixed(2)} ms';
  } else {
    return '${(microseconds / 1000000).toStringAsFixed(2)} s';
  }
}

void main() async {
  await execute();
}
