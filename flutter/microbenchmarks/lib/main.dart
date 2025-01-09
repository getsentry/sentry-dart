import 'dart:io';
import 'src/image_bench.dart' as image_bench;
import 'src/memory_bench.dart' as memory_bench;

Future<void> main() async {
  await image_bench.execute();
  await memory_bench.execute();
  print('Benchmarks finished');
  exit(0);
}
