import 'dart:io';
import 'src/image_bench.dart' as image_bench;

Future<void> main() async {
  await image_bench.execute();
  exit(0);
}
