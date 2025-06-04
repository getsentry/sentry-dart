import 'dart:async';
import 'protocol/contexts.dart';
import 'package:meta/meta.dart';

abstract class ContextsEnricher {
  @internal
  Future<Contexts> enrich(Contexts contexts);
}
