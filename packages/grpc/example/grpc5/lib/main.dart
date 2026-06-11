// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:grpc/src/generated/google/protobuf/any.pb.dart' as pb;
import 'package:grpc/src/generated/google/rpc/error_details.pb.dart' as rpc;
import 'package:grpc/src/generated/google/rpc/status.pb.dart' as rpc_status;
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
  // Local server demonstrates _attachErrorDetails by returning rich error
  // details that grpcb.in does not provide.
  final localServer = Server.create(services: [_ErrorDetailsService()]);
  await localServer.serve(address: InternetAddress.loopbackIPv4, port: 0);

  final channel = ClientChannel(
    'grpcb.in',
    port: 9001,
    options: const ChannelOptions(credentials: ChannelCredentials.secure()),
  );
  final localChannel = ClientChannel(
    'localhost',
    port: localServer.port!,
    options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
  );

  final client = _GrpcBinClient(
    channel,
    interceptors: [SentryGrpcInterceptor(captureFailedRequests: true)],
  );
  final localClient = _ErrorDetailsClient(
    localChannel,
    interceptors: [SentryGrpcInterceptor(captureFailedRequests: true)],
  );

  try {
    await _emptyCall(client);
    await _dummyUnaryCall(client);
    await _randomErrorCall(client);
    await _withHeadersCall(client);
    await _errorDetailsCall(localClient);
  } finally {
    await channel.shutdown();
    await localChannel.shutdown();
    await localServer.shutdown();
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
// as rpc.request.metadata.meat in the span data.
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

// Calls the local service which always fails with rich error details.
// The interceptor's _attachErrorDetails reads ErrorInfo and BadRequest from the
// span, so check the span data in Sentry for grpc.error_info.* and
// grpc.bad_request.field_violations attributes.
Future<void> _errorDetailsCall(_ErrorDetailsClient client) async {
  print('--- Local/GetWithDetails (error_details demo) ---');
  final tr = Sentry.startTransaction(
    'local-error-details',
    'grpc.client',
    bindToScope: true,
  );
  try {
    await client.getWithDetails();
    tr.status = const SpanStatus.ok();
    print('OK (unexpected)');
  } catch (e, s) {
    tr.throwable = e;
    tr.status = const SpanStatus.internalError();
    await Sentry.captureException(e, stackTrace: s);
    print('FAILED (expected — error details attached to span): $e');
  } finally {
    await tr.finish();
  }
}

// Encodes detail protos into the grpc-status-details-bin trailer so the grpc
// client populates GrpcError.details — matching what a real server sends.
GrpcError _buildRichGrpcError(int code) {
  final details = [
    rpc.ErrorInfo(reason: 'FIELD_INVALID', domain: 'example.sentry.io'),
    rpc.BadRequest()
      ..fieldViolations.add(
        rpc.BadRequest_FieldViolation()
          ..field_1 = 'email'
          ..description = 'Must be a valid email address',
      ),
  ];
  final anyDetails = details
      .map((d) => pb.Any.pack(d, typeUrlPrefix: 'type.googleapis.com'))
      .toList();
  final status = rpc_status.Status(code: code, details: anyDetails);
  final encoded = base64Url.encode(status.writeToBuffer());
  return GrpcError.custom(code, 'validation error', null, null, {
    'grpc-status-details-bin': encoded,
  });
}

class _ErrorDetailsService extends Service {
  @override
  String get $name => 'sentry.example.ErrorDetails';

  _ErrorDetailsService() {
    $addMethod(ServiceMethod<List<int>, List<int>>(
      'GetWithDetails',
      _handle,
      false,
      false,
      (bytes) => bytes,
      (bytes) => bytes,
    ));
  }

  Future<List<int>> _handle(
    ServiceCall call,
    Future<List<int>> request,
  ) async {
    throw _buildRichGrpcError(StatusCode.invalidArgument);
  }
}

class _ErrorDetailsClient extends Client {
  static final _getWithDetails = ClientMethod<List<int>, List<int>>(
    '/sentry.example.ErrorDetails/GetWithDetails',
    (data) => data,
    (data) => data,
  );

  _ErrorDetailsClient(super.channel, {super.interceptors});

  ResponseFuture<List<int>> getWithDetails() =>
      $createUnaryCall(_getWithDetails, const <int>[]);
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
