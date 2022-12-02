// Adapted from https://github.com/ueman/sentry-dart-tools/blob/8e41418c0f2c62dc88292cf32a4f22e79112b744/sentry_plus/lib/src/file/sentry_file.dart

// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

typedef Callback<T> = T Function();

class SentryFile implements File {
  SentryFile(
    this._file, {
    @internal Hub? hub,
  }) : _hub = hub ?? HubAdapter();

  final File _file;
  final Hub _hub;

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
    return _wrap(
      _file.create(recursive: recursive),
      'file.create',
    );
  }

  @override
  void createSync({bool recursive = false, bool exclusive = false}) {
    return _wrapSync(
      () => _file.createSync(recursive: recursive),
      'file.create',
    );
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    return _wrap(_file.delete(recursive: recursive), 'file.delete');
  }

  @override
  void deleteSync({bool recursive = false}) {
    _wrapSync(() => _file.deleteSync(recursive: recursive), 'file.delete');
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
  Future<Uint8List> readAsBytes() {
    return _wrap(_file.readAsBytes(), 'file.read');
  }

  @override
  Uint8List readAsBytesSync() {
    return _wrapSync(() => _file.readAsBytesSync(), 'file.read');
  }

  @override
  Future<List<String>> readAsLines({Encoding encoding = utf8}) {
    return _wrap(_file.readAsLines(encoding: encoding), 'file.read');
  }

  @override
  List<String> readAsLinesSync({Encoding encoding = utf8}) {
    return _wrapSync(
      () => _file.readAsLinesSync(encoding: encoding),
      'file.read',
    );
  }

  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    return _wrap(_file.readAsString(encoding: encoding), 'file.read');
  }

  @override
  String readAsStringSync({Encoding encoding = utf8}) {
    return _wrapSync(
      () => _file.readAsStringSync(encoding: encoding),
      'file.read',
    );
  }

  @override
  Future<File> rename(String newPath) {
    return _wrap(_file.rename(newPath), 'file.rename');
  }

  @override
  File renameSync(String newPath) {
    return _wrapSync(() => _file.renameSync(newPath), 'file.rename');
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
    _wrapSync(
      () => _file.writeAsBytesSync(bytes, mode: mode, flush: flush),
      'file.write',
    );
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    return _wrap(
      _file.writeAsString(
        contents,
        mode: mode,
        encoding: encoding,
        flush: flush,
      ),
      'file.write',
    );
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    _wrapSync(
      () => _file.writeAsStringSync(
        contents,
        mode: mode,
        encoding: encoding,
        flush: flush,
      ),
      'file.write',
    );
  }

  Future<T> _wrap<T>(Future<T> future, String operation) async {
    final span = _hub.getSpan()?.startChild(operation, description: _file.path);
    span?.setData('async-io', true);
    if (_hub.options.sendDefaultPii) {
      // if (_hub.options.sendDefaultPii || _hub.options.platformChecker.isMobile) {
      span?.setData('file.path', path);
    }
    T data;
    try {
      data = await future;
      if (data is List<int>) {
        span?.setData('file.size', data.length);
      }
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
    span?.setData('async-io', false);

    if (_hub.options.sendDefaultPii) {
      // if (_hub.options.sendDefaultPii || _hub.options.platformChecker.isMobile) {
      span?.setData('file.path', path);
    }
    T data;
    try {
      data = callback();
      if (data is List<int>) {
        span?.setData('file.size', data.length);
      }
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

  // coverage:ignore-start

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) =>
      _file.watch(events: events, recursive: recursive);

  @override
  Future<String> resolveSymbolicLinks() => _file.resolveSymbolicLinks();

  @override
  String resolveSymbolicLinksSync() => _file.resolveSymbolicLinksSync();

  @override
  Future setLastAccessed(DateTime time) => _file.setLastAccessed(time);

  @override
  void setLastAccessedSync(DateTime time) => _file.setLastAccessedSync(time);

  @override
  Future setLastModified(DateTime time) => _file.setLastModified(time);

  @override
  void setLastModifiedSync(DateTime time) => _file.setLastAccessedSync(time);

  @override
  Directory get parent => _file.parent;

  @override
  String get path => _file.path;

  @override
  File get absolute => _file.absolute;

  @override
  Future<bool> exists() => _file.exists();

  @override
  bool existsSync() => _file.existsSync();

  @override
  bool get isAbsolute => _file.isAbsolute;

  @override
  Future<DateTime> lastAccessed() => _file.lastAccessed();

  @override
  DateTime lastAccessedSync() => _file.lastAccessedSync();

  @override
  Future<DateTime> lastModified() => _file.lastModified();

  @override
  DateTime lastModifiedSync() => _file.lastModifiedSync();

  @override
  Future<int> length() => _file.length();

  @override
  int lengthSync() => _file.lengthSync();

  @override
  Future<FileStat> stat() => _file.stat();

  @override
  FileStat statSync() => _file.statSync();

  @override
  Uri get uri => _file.uri;

  // coverage:ignore-end
}

// extension on PlatformChecker {
//   bool get isMobile {
//     return platform.isIOS || platform.isAndroid;
//   }
// }
