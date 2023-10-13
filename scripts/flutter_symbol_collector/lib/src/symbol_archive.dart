import 'package:platform/platform.dart';
import 'package:meta/meta.dart';

@immutable
class SymbolArchive {
  final String path;
  final Platform platform;

  SymbolArchive(this.path, this.platform);
}
