import 'dart:convert';

import 'package:grpc/grpc.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_grpc/sentry_grpc.dart';

import 'app_config.dart' as config;

Future<void> main() async {
  await Sentry.init(
    (options) {
      options.dsn = config.exampleDsn;
      options.tracesSampleRate = 1.0;
      options.captureFailedRequests = true;
      options.debug = true;
    },
    appRunner: _runApp,
  );
}

Future<void> _runApp() async {
  final channel = ClientChannel(
    'grpcb.in',
    port: 9001,
    options: const ChannelOptions(credentials: ChannelCredentials.secure()),
  );
  final client = _GrpcBinClient(
    channel,
    interceptors: [SentryGrpcInterceptor(captureFailedRequests: true)],
  );

  try {
    await _emptyCall(client);
    await _dummyUnaryCall(client);
    await _randomErrorCall(client);
  } finally {
    await channel.shutdown();
    await Sentry.close();
  }
}

Future<void> _emptyCall(_GrpcBinClient client) async {
  print('--- GRPCBin/Empty ---');
  final tr = Sentry.startTransaction(
    'grpcb-empty',
    'grpc.client',
    bindToScope: true,
  );
  try {
    await client.empty();
    tr.status = const SpanStatus.ok();
    print('OK');
  } catch (e, s) {
    tr.throwable = e;
    tr.status = const SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    print('FAILED: $e');
  } finally {
    await tr.finish();
  }
}

Future<void> _dummyUnaryCall(_GrpcBinClient client) async {
  print('--- GRPCBin/DummyUnary ---');
  final tr = Sentry.startTransaction(
    'grpcb-dummy-unary',
    'grpc.client',
    bindToScope: true,
  );
  try {
    final response = await client.dummyUnary(
      _encodeDummyMessage('hello from sentry_grpc'),
    );
    tr.status = const SpanStatus.ok();
    print('echo: "${_decodeDummyFString(response)}"');
  } catch (e, s) {
    tr.throwable = e;
    tr.status = const SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    print('FAILED: $e');
  } finally {
    await tr.finish();
  }
}

Future<void> _randomErrorCall(_GrpcBinClient client) async {
  print('--- GRPCBin/RandomError ---');
  final tr = Sentry.startTransaction(
    'grpcb-random-error',
    'grpc.client',
    bindToScope: true,
  );
  try {
    await client.randomError();
    tr.status = const SpanStatus.ok();
    print('OK');
  } catch (e, s) {
    tr.throwable = e;
    tr.status = const SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    print('FAILED: $e');
  } finally {
    await tr.finish();
  }
}

List<int> _encodeDummyMessage(String value) {
  final bytes = utf8.encode(value);
  return [0x0A, bytes.length, ...bytes];
}

String _decodeDummyFString(List<int> bytes) {
  if (bytes.length < 2 || bytes[0] != 0x0A) return '(no f_string)';
  final len = bytes[1];
  if (bytes.length < 2 + len) return '(truncated)';
  return utf8.decode(bytes.sublist(2, 2 + len));
}

class _GrpcBinClient extends Client {
  static final _emptyCall = ClientMethod<List<int>, List<int>>(
    '/grpcbin.GRPCBin/Empty',
    (data) => data,
    (data) => data,
  );

  static final _dummyUnaryCall = ClientMethod<List<int>, List<int>>(
    '/grpcbin.GRPCBin/DummyUnary',
    (data) => data,
    (data) => data,
  );

  static final _randomErrorCall = ClientMethod<List<int>, List<int>>(
    '/grpcbin.GRPCBin/RandomError',
    (data) => data,
    (data) => data,
  );

  _GrpcBinClient(super.channel, {super.interceptors});

  ResponseFuture<List<int>> empty() =>
      $createUnaryCall(_emptyCall, const <int>[]);

  ResponseFuture<List<int>> dummyUnary(List<int> request) =>
      $createUnaryCall(_dummyUnaryCall, request);

  ResponseFuture<List<int>> randomError() =>
      $createUnaryCall(_randomErrorCall, const <int>[]);
}
