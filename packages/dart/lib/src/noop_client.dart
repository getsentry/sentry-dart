import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart';

class NoOpClient implements Client {
  NoOpClient._();

  static final NoOpClient _instance = NoOpClient._();

  static final Future<Response> _response = Future.value(Response('', 500));
  static final Future<String> _string = Future.value('');
  static final Future<Uint8List> _intList = Future.value(Uint8List(0));
  static final Future<StreamedResponse> _streamedResponse =
      Future.value(StreamedResponse(Stream.empty(), 500));

  factory NoOpClient() {
    return _instance;
  }

  @override
  void close() {}

  @override
  Future<Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) =>
      _response;

  @override
  Future<Response> get(url, {Map<String, String>? headers}) => _response;

  @override
  Future<Response> head(url, {Map<String, String>? headers}) => _response;

  @override
  Future<Response> patch(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _response;

  @override
  Future<Response> post(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _response;

  @override
  Future<Response> put(url,
          {Map<String, String>? headers, body, Encoding? encoding}) =>
      _response;

  @override
  Future<String> read(url, {Map<String, String>? headers}) => _string;

  @override
  Future<Uint8List> readBytes(url, {Map<String, String>? headers}) => _intList;

  @override
  Future<StreamedResponse> send(BaseRequest request) => _streamedResponse;
}
