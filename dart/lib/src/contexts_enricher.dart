import 'dart:async';
import 'protocol/contexts.dart';
import 'package:meta/meta.dart';

@internal
abstract class ContextsEnricher {
  FutureOr<void> enrich(Contexts contexts);
}
