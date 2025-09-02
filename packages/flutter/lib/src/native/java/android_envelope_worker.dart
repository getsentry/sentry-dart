class AndroidEnvelopeWorker extends WorkerIsolate {
  AndroidEnvelopeWorker(super.config);

  static Future<SendPort> spawn(WorkerConfig config) async {
    // 1) Create a ReceivePort the worker can talk to immediately.
    final init = ReceivePort();

    // 2) Pass BOTH the config and init.sendPort into the isolate.
    await Isolate.spawn<(WorkerConfig, SendPort)>(
      AndroidEnvelopeWorker.entryPoint,
      (config, init.sendPort),
      debugName: 'SentryAndroidEnvelopeWorker',
    );

    // 3) First message from worker is its inbox SendPort.
    final SendPort workerInbox = await init.first as SendPort;
    return workerInbox;
  }

  void startMessageLoop() {
    final receivePort = ReceivePort();

    // Handshake: tell host how to send messages to this worker.
    hostPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      try {
        processMessage(message);
      } catch (e, st) {
        // sendError(e, st);
      }
    });
  }

  void processMessage(dynamic message) {
    IsolateDiagnosticLog.log(SentryLevel.warning,
        'EnvelopeWorker invoked; starting captureEnvelope');

    if (message is TransferableTypedData) {
      final envelopeData = message.materialize().asUint8List();
      _captureEnvelope(envelopeData, false);
    }
  }

  void _captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    JObject? id;
    JByteArray? byteArray;
    try {
      byteArray = JByteArray.from(envelopeData);
      id = native.InternalSentrySdk.captureEnvelope(
          byteArray, containsUnhandledException);

      if (id == null) {
        IsolateDiagnosticLog.log(SentryLevel.error,
            'Native Android SDK returned null id when capturing envelope');
      }
    } catch (exception, stackTrace) {
      IsolateDiagnosticLog.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);
      // if (options.automatedTestMode) {
      //   rethrow;
      // }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }

  void send(Object message) => hostPort.send(message);

  static void entryPoint((WorkerConfig, SendPort) args) {
    final (config, hostPort) = args;

    final level = config.environment['logLevel'] as SentryLevel;
    final debug = config.environment['debug'] as bool;
    IsolateDiagnosticLog.configure(debug: debug, level: level);
    IsolateDiagnosticLog.log(
        SentryLevel.warning, 'AndroidEnvelopeWorker started');

    // Construct worker with the hostPort we just received.
    final worker = AndroidEnvelopeWorker(config);

    // Start loop and complete the handshake by sending our inbox SendPort.
    final receivePort = ReceivePort();
    hostPort.send(receivePort.sendPort); // <- completes init.first in spawn()

    // Option A: reuse startMessageLoop’s listener:
    receivePort.listen(worker.processMessage);

    // Option B: if you prefer your existing method, you can:
    // worker.startMessageLoop();
    // but then remove the duplicate handshake above from startMessageLoop, or
    // let startMessageLoop accept the already-created receivePort.
  }
}
