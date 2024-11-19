import 'dart:async';

import 'package:http/http.dart';
import 'package:sentry/src/utils/streamed_response_copier.dart';
import 'package:test/test.dart';

void main() {
  group('StreamedResponseCopier', () {
    late StreamController<List<int>> streamController;
    late StreamedResponse originalResponse;
    late StreamedResponseCopier copier;

    setUp(() {
      streamController = StreamController<List<int>>();
      originalResponse = StreamedResponse(
        streamController.stream,
        200,
        contentLength: 100,
        headers: {'Content-Type': 'application/json'},
        reasonPhrase: 'OK',
      );
      copier = StreamedResponseCopier(originalResponse);
    });

    tearDown(() {
      copier.dispose();
    });

    test('forwards original stream data to copies', () async {
      final copiedResponse = copier.copy();
      final receivedData = <List<int>>[];

      copiedResponse.stream.listen(receivedData.add);

      streamController.add([1, 2, 3]);
      streamController.add([4, 5, 6]);
      await streamController.close();

      await Future.delayed(Duration(milliseconds: 100)); // Wait for async tasks
      expect(receivedData, [
        [1, 2, 3],
        [4, 5, 6]
      ]);
    });

    test('caches data and replays in subsequent copies', () async {
      streamController.add([1, 2, 3]);
      await Future.delayed(Duration(milliseconds: 100)); // Wait for cache

      final copiedResponse = copier.copy();
      final receivedData = <List<int>>[];

      copiedResponse.stream.listen(receivedData.add);
      await Future.delayed(Duration(milliseconds: 100)); // Wait for replay

      expect(receivedData, [
        [1, 2, 3]
      ]);
    });

    test('handles errors in the original stream', () async {
      final copiedResponse = copier.copy();
      final errors = <Object>[];

      copiedResponse.stream.listen(
        (_) {},
        onError: errors.add,
      );

      streamController.addError(Exception('Test error'));
      await Future.delayed(Duration(milliseconds: 100)); // Wait for async tasks

      expect(errors.length, 1);
      expect(errors.first.toString(), contains('Test error'));
    });

    test('closes copied streams when original stream is done', () async {
      final copiedResponse = copier.copy();
      final isDone = Completer<bool>();

      copiedResponse.stream.listen(
        (_) {},
        onDone: () => isDone.complete(true),
      );

      await streamController.close();

      expect(await isDone.future, isTrue);
    });

    test('disposes resources correctly', () async {
      await copier.dispose();

      expect(
        () => copier.copy(),
        throwsStateError,
      );
    });

    test('copies include original response metadata', () {
      final copiedResponse = copier.copy();

      expect(copiedResponse.statusCode, originalResponse.statusCode);
      expect(copiedResponse.contentLength, originalResponse.contentLength);
      expect(copiedResponse.headers, originalResponse.headers);
      expect(copiedResponse.reasonPhrase, originalResponse.reasonPhrase);
    });

    test('streams replay cached data and listen to future updates', () async {
      streamController.add([1, 2, 3]);
      await Future.delayed(Duration(milliseconds: 100)); // Wait for cache

      final copiedResponse = copier.copy();
      final receivedData = <List<int>>[];

      copiedResponse.stream.listen(receivedData.add);
      await Future.delayed(Duration(milliseconds: 100)); // Wait for cache
      streamController.add([4, 5, 6]);
      await streamController.close();

      expect(receivedData, [
        [1, 2, 3],
        [4, 5, 6]
      ]);
    });
  });
}
