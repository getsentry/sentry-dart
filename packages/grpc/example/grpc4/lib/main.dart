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
      title: 'sentry_grpc — grpc 4',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
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
        final transaction = Sentry.startTransaction(
          'good-request',
          'http.client',
          bindToScope: true,
        );
        try {
          final response =
              await http.get(Uri.parse('https://rsa4096.badssl.com/'));
          transaction.status = response.statusCode < 400
              ? const SpanStatus.ok()
              : const SpanStatus.internalError();
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

  Future<void> _badRequest() => _run('Bad request', () async {
        final transaction = Sentry.startTransaction(
          'bad-request',
          'http.client',
          bindToScope: true,
        );
        try {
          final response =
              await http.get(Uri.parse('https://expired.badssl.com/'));
          transaction.status = response.statusCode < 400
              ? const SpanStatus.ok()
              : const SpanStatus.internalError();
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
            _encodeDummyMessage('hello from sentry_grpc'),
          );
          transaction.status = const SpanStatus.ok();
          return 'echo: "${_decodeDummyFString(response)}"';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('sentry_grpc — grpc 4'),
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

// Proto-encodes DummyMessage { f_string: value } (field 1, wire type 2).
List<int> _encodeDummyMessage(String value) {
  final bytes = utf8.encode(value);
  return [0x0A, bytes.length, ...bytes];
}

// Decodes f_string from a DummyMessage byte payload (field 1, wire type 2).
String _decodeDummyFString(List<int> bytes) {
  if (bytes.length < 2 || bytes[0] != 0x0A) return '(no f_string)';
  final len = bytes[1];
  if (bytes.length < 2 + len) return '(truncated)';
  return utf8.decode(bytes.sublist(2, 2 + len));
}

// Minimal gRPC client for grpcb.in.
// Messages with no fields (EmptyMessage) serialize to/from an empty byte list.
// DummyMessage is hand-encoded — see proto helpers above.
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
