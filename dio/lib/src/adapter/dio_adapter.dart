// ignore_for_file: public_member_api_docs

import 'package:dio/dio.dart';

import '_io_adapter.dart' if (dart.library.html) '_browser_adapter.dart'
    as adapter;

HttpClientAdapter createAdapter() => adapter.createAdapter();
