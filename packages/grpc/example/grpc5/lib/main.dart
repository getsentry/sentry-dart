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
    await _withHeadersCall(client);
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
      const DummyMessage(fString: 'hello from sentry_grpc'),
    );
    tr.status = const SpanStatus.ok();
    print('echo: "${response.fString}"');
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

// Demonstrates request header capture: 'meat: vegetable' will appear
// as http.request.header.meat in the span data.
Future<void> _withHeadersCall(_GrpcBinClient client) async {
  print('--- GRPCBin/DummyUnary with headers ---');
  final tr = Sentry.startTransaction(
    'grpcb-with-headers',
    'grpc.client',
    bindToScope: true,
  );
  try {
    final response = await client.dummyUnaryWithHeaders(
      const DummyMessage(fString: 'bar', fInt32: 42),
    );
    tr.status = const SpanStatus.ok();
    print('echo: "${response.fString}"');
  } catch (e, s) {
    tr.throwable = e;
    tr.status = const SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    print('FAILED: $e');
  } finally {
    await tr.finish();
  }
}

class DummyMessage {
  const DummyMessage({this.fString = '', this.fInt32 = 0});

  factory DummyMessage.fromBytes(List<int> bytes) {
    String fString = '';
    int fInt32 = 0;
    int i = 0;
    while (i < bytes.length) {
      final tag = bytes[i++];
      final field = tag >> 3;
      final wireType = tag & 0x7;
      if (field == 1 && wireType == 2) {
        final len = bytes[i++];
        fString = utf8.decode(bytes.sublist(i, i + len));
        i += len;
      } else if (field == 3 && wireType == 0) {
        fInt32 = bytes[i++];
      } else {
        break;
      }
    }
    return DummyMessage(fString: fString, fInt32: fInt32);
  }

  final String fString;
  final int fInt32;

  List<int> toBytes() {
    final result = <int>[];
    if (fString.isNotEmpty) {
      final encoded = utf8.encode(fString);
      result.addAll([0x0A, encoded.length, ...encoded]);
    }
    if (fInt32 != 0) {
      result.addAll([0x18, fInt32]);
    }
    return result;
  }
}

class _GrpcBinClient extends Client {
  static final _emptyCall = ClientMethod<List<int>, List<int>>(
    '/grpcbin.GRPCBin/Empty',
    (data) => data,
    (data) => data,
  );

  static final _dummyUnaryCall = ClientMethod<DummyMessage, DummyMessage>(
    '/grpcbin.GRPCBin/DummyUnary',
    (msg) => msg.toBytes(),
    DummyMessage.fromBytes,
  );

  static final _randomErrorCall = ClientMethod<List<int>, List<int>>(
    '/grpcbin.GRPCBin/RandomError',
    (data) => data,
    (data) => data,
  );

  _GrpcBinClient(super.channel, {super.interceptors});

  ResponseFuture<List<int>> empty() =>
      $createUnaryCall(_emptyCall, const <int>[]);

  ResponseFuture<DummyMessage> dummyUnary(DummyMessage request) =>
      $createUnaryCall(_dummyUnaryCall, request);

  ResponseFuture<DummyMessage> dummyUnaryWithHeaders(DummyMessage request) =>
      $createUnaryCall(
        _dummyUnaryCall,
        request,
        options: CallOptions(metadata: {'meat': 'vegetable'}),
      );

  ResponseFuture<List<int>> randomError() =>
      $createUnaryCall(_randomErrorCall, const <int>[]);
}
