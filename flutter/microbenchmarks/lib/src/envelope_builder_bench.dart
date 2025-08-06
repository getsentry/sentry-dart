import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';

const _numberOfIterations = 1000;

Future<void> execute() async {
  print('Envelope Builder Benchmark');
  print('==========================');
  print('Comparing legacy List<int> vs BytesBuilder approaches\n');

  // Test with different envelope sizes
  final sizes = [
    (1024, '1 KB'), // Small envelope
    (10 * 1024, '10 KB'), // Medium envelope
    (100 * 1024, '100 KB'), // Large envelope
    (1024 * 1024, '1 MB'), // Very large envelope
  ];

  for (final (size, label) in sizes) {
    print('Envelope size: $label');
    print('-' * 40);

    // Create mock envelope data
    final mockData = _generateMockEnvelopeData(size);

    // Benchmark legacy approach
    final legacyResults = await _benchmarkLegacyApproach(mockData);
    final legacyAvg = legacyResults.reduce((a, b) => a + b) /
        legacyResults.length;
    final legacyMin = legacyResults.reduce(min);
    final legacyMax = legacyResults.reduce(max);

    // Benchmark new approach
    final newResults = await _benchmarkNewApproach(mockData);
    final newAvg = newResults.reduce((a, b) => a + b) / newResults.length;
    final newMin = newResults.reduce(min);
    final newMax = newResults.reduce(max);

    final newReusedResults = await _benchmarkNewApproachWithReuse(mockData);
    final newReusedAvg = newReusedResults.reduce((a, b) => a + b) / newReusedResults.length;
    final newReusedMin = newReusedResults.reduce(min);
    final newReusedMax = newReusedResults.reduce(max);

    print('New approach reused (BytesBuilder):');
    print('  Average: ${_formatMicroseconds(newReusedAvg)}');
    print('  Min: ${_formatMicroseconds(newReusedMin)}');
    print('  Max: ${_formatMicroseconds(newReusedMax)}');

    // Calculate improvement
    final improvement = ((legacyAvg - newAvg) / legacyAvg * 100)
        .toStringAsFixed(1);
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

Future<List<double>> _benchmarkLegacyApproach(List<List<int>> chunks) async {
  final results = <double>[];

  // Warmup
  for (var i = 0; i < 100; i++) {
    _runLegacyApproach(chunks);
  }

  // Actual benchmark
  for (var i = 0; i < _numberOfIterations; i++) {
    final stopwatch = Stopwatch()
      ..start();
    _runLegacyApproach(chunks);
    stopwatch.stop();
    results.add(stopwatch.elapsedMicroseconds.toDouble());
  }

  return results;
}

Future<List<double>> _benchmarkNewApproach(List<List<int>> chunks) async {
  final results = <double>[];

  // Warmup
  for (var i = 0; i < 100; i++) {
    _runNewApproach(chunks);
  }

  // Actual benchmark
  for (var i = 0; i < _numberOfIterations; i++) {
    final stopwatch = Stopwatch()
      ..start();
    _runNewApproach(chunks);
    stopwatch.stop();
    results.add(stopwatch.elapsedMicroseconds.toDouble());
  }

  return results;
}

Future<List<double>> _benchmarkNewApproachWithReuse(List<List<int>> chunks) async {
  final results = <double>[];

  // Warmup
  for (var i = 0; i < 100; i++) {
    _runNewApproachWithReusedByteBuilder(chunks);
  }

  // Actual benchmark
  for (var i = 0; i < _numberOfIterations; i++) {
    final stopwatch = Stopwatch()
      ..start();
    _runNewApproachWithReusedByteBuilder(chunks);
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

final reUserByteBuilder = BytesBuilder(copy: false);
Uint8List _runNewApproachWithReusedByteBuilder(List<List<int>> chunks) {
  for (final chunk in chunks) {
    reUserByteBuilder.add(chunk);
  }
  return reUserByteBuilder.takeBytes();
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
