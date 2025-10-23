import 'package:http/http.dart';
import 'dart:convert';

class MockClient extends BaseClient {
  final sendCalls = <BaseRequest>[];
  final closeCalls = <void>[];

  var jsonResponse = '{}';
  var statusCode = 200;
  dynamic throwException;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    sendCalls.add(request);
    if (throwException != null && throwException is Object) {
      throw throwException as Object;
    }
    return StreamedResponse(
      Stream.value(utf8.encode(jsonResponse)),
      statusCode,
    );
  }

  @override
  void close() {
    closeCalls.add(null);
  }
}
