import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import '../protocol/span_status.dart';

import '../hub.dart';

typedef Callback<T> = T Function();

class SentryFile implements File {
  SentryFile(this._file, this._hub);

  final File _file;
  final Hub _hub;

  @override
  File get absolute => _file.absolute;

  @override
  Future<File> copy(String newPath) {
    return _wrap(_file.copy(newPath), 'file.copy');
  }

  @override
  File copySync(String newPath) {
    return _wrapSync(() => _file.copySync(newPath), 'file.copy');
  }

  @override
  Future<File> create({bool recursive = false}) {
    return _wrap(_file.create(recursive: recursive), 'file.create');
  }

  @override
  void createSync({bool recursive = false}) {
    return _wrapSync(
        () => _file.createSync(recursive: recursive), 'file.create');
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    return _wrap(_file.delete(recursive: recursive), 'file.delete');
  }

  @override
  void deleteSync({bool recursive = false}) {
    return _file.deleteSync(recursive: recursive);
  }

  @override
  Future<bool> exists() {
    return _file.exists();
  }

  @override
  bool existsSync() {
    return _file.existsSync();
  }

  @override
  bool get isAbsolute => _file.isAbsolute;

  @override
  Future<DateTime> lastAccessed() {
    return _file.lastAccessed();
  }

  @override
  DateTime lastAccessedSync() {
    return _file.lastAccessedSync();
  }

  @override
  Future<DateTime> lastModified() {
    return _file.lastModified();
  }

  @override
  DateTime lastModifiedSync() {
    return _file.lastModifiedSync();
  }

  @override
  Future<int> length() {
    return _wrap(_file.length(), 'file.read');
  }

  @override
  int lengthSync() {
    return _file.lengthSync();
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) {
    return _wrap(_file.open(mode: mode), 'file.open');
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) {
    return _file.openRead(start, end);
  }

  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) {
    return _file.openSync(mode: mode);
  }

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    return _file.openWrite(mode: mode, encoding: encoding);
  }

  @override
  Directory get parent => _file.parent;

  @override
  String get path => _file.path;

  @override
  Future<Uint8List> readAsBytes() {
    return _wrap(_file.readAsBytes(), 'file.read');
  }

  @override
  Uint8List readAsBytesSync() {
    return _file.readAsBytesSync();
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) {
    return _wrap(_file.readAsLines(encoding: encoding), 'file.read');
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    return _file.readAsLinesSync(encoding: encoding);
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    return _wrap(_file.readAsString(encoding: encoding), 'file.read');
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return _file.readAsStringSync(encoding: encoding);
  }

  @override
  Future<File> rename(String newPath) {
    return _wrap(_file.rename(newPath), 'file.rename');
  }

  @override
  File renameSync(String newPath) {
    return _file.renameSync(newPath);
  }

  @override
  Future<String> resolveSymbolicLinks() {
    return _file.resolveSymbolicLinks();
  }

  @override
  String resolveSymbolicLinksSync() {
    return _file.resolveSymbolicLinksSync();
  }

  @override
  Future setLastAccessed(DateTime time) {
    return _file.setLastAccessed(time);
  }

  @override
  void setLastAccessedSync(DateTime time) {
    _file.setLastAccessedSync(time);
  }

  @override
  Future setLastModified(DateTime time) {
    return _file.setLastModified(time);
  }

  @override
  void setLastModifiedSync(DateTime time) {
    _file.setLastAccessedSync(time);
  }

  @override
  Future<FileStat> stat() {
    return _file.stat();
  }

  @override
  FileStat statSync() {
    return _file.statSync();
  }

  @override
  Uri get uri => _file.uri;

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    return _file.watch(events: events, recursive: recursive);
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    return _wrap(
      _file.writeAsBytes(bytes, mode: mode, flush: flush),
      'file.write',
    );
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    _file.writeAsBytesSync(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    return _wrap(_file.writeAsString(contents), 'file.write');
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    _file.writeAsStringSync(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
  }

  Future<T> _wrap<T>(Future<T> future, String operation) async {
    final span = _hub.getSpan()?.startChild(operation, description: _file.path);

    T data;
    try {
      data = await future;
      span?.status = SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span?.finish();
    }
    return data;
  }

  T _wrapSync<T>(Callback<T> callback, String operation) {
    final span = _hub.getSpan()?.startChild(operation, description: _file.path);

    T data;
    try {
      data = callback();
      span?.status = SpanStatus.ok();
    } catch (exception) {
      span?.throwable = exception;
      span?.status = SpanStatus.internalError();
      rethrow;
    } finally {
      span?.finish();
    }
    return data;
  }
}
