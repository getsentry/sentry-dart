// coverage:ignore-file
// ignore_for_file: public_member_api_docs

import 'package:dio/adapter_browser.dart';
import 'package:dio/dio.dart';

HttpClientAdapter createAdapter() => BrowserHttpClientAdapter();
