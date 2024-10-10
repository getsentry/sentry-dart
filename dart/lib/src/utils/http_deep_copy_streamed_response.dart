import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// Helper to deep copy the StreamedResponse of a web request
@internal
Future<List<StreamedResponse>> deepCopyStreamedResponse(
    StreamedResponse originalResponse, int copies) async {
  final List<int> bufferedData = [];

  await for (final List<int> chunk in originalResponse.stream) {
    bufferedData.addAll(chunk);
  }

  List<StreamedResponse> copiedElements = [];
  for (int i = 1; i <= copies; i++) {
    copiedElements.add(StreamedResponse(
      Stream.fromIterable([bufferedData]),
      originalResponse.statusCode,
      contentLength: originalResponse.contentLength,
      request: originalResponse.request,
      headers: originalResponse.headers,
      reasonPhrase: originalResponse.reasonPhrase,
      isRedirect: originalResponse.isRedirect,
      persistentConnection: originalResponse.persistentConnection,
    ));
  }
  return copiedElements;
}
