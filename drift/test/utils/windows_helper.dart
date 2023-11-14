import 'dart:ffi';
import 'dart:io';

DynamicLibrary openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}/test/sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}