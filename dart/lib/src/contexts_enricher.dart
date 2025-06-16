import 'dart:async';
import 'protocol/contexts.dart';
import 'package:meta/meta.dart';

abstract class ContextsEnricher {
  @internal
  Future<void> enrich(Contexts contexts);
}
