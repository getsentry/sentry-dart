import 'package:meta/meta.dart';

abstract class SentryEncodable {
  @internal
  Map<String, dynamic> toJson();
}
