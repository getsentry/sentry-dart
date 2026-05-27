import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';
import 'package:sentry_grpc/sentry_grpc.dart';
import 'app_config.dart' as config;

void main() async {
  await Sentry.init(
    (options) {
      options.dsn = config.exampleDsn;
      options.tracesSampleRate = 1.0;
      options.debug = true;
    },
    appRunner: () => runApp(const App()),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sentry_grpc — grpc 5',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B894)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _result = 'Tap a button to send a request.';
  bool _loading = false;

  late final _GrpcBinClient _grpcClient;
  late final ClientChannel _channel;

  @override
  void initState() {
    super.initState();
    _channel = ClientChannel(
      'grpcb.in',
      port: 9001,
      options: const ChannelOptions(credentials: ChannelCredentials.secure()),
    );
    _grpcClient = _GrpcBinClient(
      _channel,
      interceptors: [SentryGrpcInterceptor(captureFailedRequests: true)],
    );
  }

  @override
  void dispose() {
    _channel.shutdown();
    super.dispose();
  }

  Future<void> _run(String label, Future<String?> Function() work) async {
    setState(() {
      _loading = true;
      _result = '$label…';
    });
    try {
      final detail = await work();
      if (mounted) setState(() => _result = detail ?? '$label — done ✓');
    } catch (e) {
      if (mounted) setState(() => _result = '$label — failed:\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goodRequest() => _run('Good request', () async {
        try {
          await http.get(Uri.parse('https://rsa4096.badssl.com/'));
        } catch (e, s) {
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        }
        return null;
      });

  Future<void> _badRequest() => _run('Bad request', () async {
        try {
          await http.get(Uri.parse('https://expired.badssl.com/'));
        } catch (e, s) {
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        }
        return null;
      });

  Future<void> _grpcRequest() => _run('gRPC request', () async {
        final transaction = Sentry.startTransaction(
          'grpcb-empty',
          'grpc.client',
          bindToScope: true,
        );
        try {
          await _grpcClient.empty();
          transaction.status = const SpanStatus.ok();
        } catch (e, s) {
          transaction.throwable = e;
          transaction.status = const SpanStatus.internalError();
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        } finally {
          await transaction.finish();
        }
        return null;
      });

  Future<void> _dummyUnaryRequest() => _run('DummyUnary', () async {
        final transaction = Sentry.startTransaction(
          'grpcb-dummy-unary',
          'grpc.client',
          bindToScope: true,
        );
        try {
          final response = await _grpcClient.dummyUnary(
            const DummyMessage(fString: 'hello from sentry_grpc'),
          );
          transaction.status = const SpanStatus.ok();
          return 'echo: "${response.fString}"';
        } catch (e, s) {
          transaction.throwable = e;
          transaction.status = const SpanStatus.internalError();
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        } finally {
          await transaction.finish();
        }
      });

  Future<void> _randomErrorRequest() => _run('RandomError', () async {
        final transaction = Sentry.startTransaction(
          'grpcb-random-error',
          'grpc.client',
          bindToScope: true,
        );
        try {
          await _grpcClient.randomError();
          transaction.status = const SpanStatus.ok();
        } catch (e, s) {
          transaction.throwable = e;
          transaction.status = const SpanStatus.internalError();
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        } finally {
          await transaction.finish();
        }
        return null;
      });

  Future<void> _withHeadersRequest() => _run('WithHeaders', () async {
        final transaction = Sentry.startTransaction(
          'grpcb-with-headers',
          'grpc.client',
          bindToScope: true,
        );
        try {
          const request = DummyMessage(fString: 'bar', fInt32: 42);
          final response = await _grpcClient.dummyUnaryWithHeaders(request);
          transaction.status = const SpanStatus.ok();
          return 'echo: "${response.fString}"';
        } catch (e, s) {
          transaction.throwable = e;
          transaction.status = const SpanStatus.internalError();
          await Sentry.captureException(e, stackTrace: s);
          rethrow;
        } finally {
          await transaction.finish();
        }
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('sentry_grpc — grpc 5'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _result,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _RequestButton(
                  label: 'Good Request',
                  subtitle: 'rsa4096.badssl.com',
                  color: Colors.green.shade600,
                  onPressed: _loading ? null : _goodRequest,
                ),
                const SizedBox(height: 12),
                _RequestButton(
                  label: 'Bad Request',
                  subtitle: 'expired.badssl.com',
                  color: Colors.red.shade600,
                  onPressed: _loading ? null : _badRequest,
                ),
                const SizedBox(height: 12),
                _RequestButton(
                  label: 'gRPC Request',
                  subtitle: 'grpcb.in:9001 — GRPCBin/Empty',
                  color: theme.colorScheme.primary,
                  onPressed: _loading ? null : _grpcRequest,
                ),
                const SizedBox(height: 12),
                _RequestButton(
                  label: 'DummyUnary',
                  subtitle: 'grpcb.in:9001 — GRPCBin/DummyUnary',
                  color: Colors.orange.shade700,
                  onPressed: _loading ? null : _dummyUnaryRequest,
                ),
                const SizedBox(height: 12),
                _RequestButton(
                  label: 'RandomError',
                  subtitle: 'grpcb.in:9001 — GRPCBin/RandomError',
                  color: Colors.purple.shade600,
                  onPressed: _loading ? null : _randomErrorRequest,
                ),
                const SizedBox(height: 12),
                _RequestButton(
                  label: 'WithHeaders',
                  subtitle: 'grpcb.in:9001 — DummyUnary + meat: vegetable',
                  color: Colors.teal.shade600,
                  onPressed: _loading ? null : _withHeadersRequest,
                ),
                if (_loading) ...[
                  const SizedBox(height: 32),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  const _RequestButton({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Typed representation of grpcb.in's DummyMessage proto.
///
/// Handles only the fields used by this example (f_string, f_int32).
/// Wire format matches the proto definition so it interoperates with grpcb.in.
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

  @override
  String toString() => 'DummyMessage(fString: "$fString", fInt32: $fInt32)';
}

// Minimal gRPC client for grpcb.in.
// EmptyMessage has no fields and serializes to/from an empty byte list.
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
