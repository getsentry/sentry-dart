import '../../event_processor.dart';
import '../../protocol.dart';
import '../../hint.dart';
import '../../sentry_options.dart';

/// Group exceptions into a flat list with references to hierarchy.
class ExceptionGroupEventProcessor implements EventProcessor {
  final SentryOptions _options;

  ExceptionGroupEventProcessor(this._options);

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final sentryExceptions = event.exceptions ?? [];
    if (sentryExceptions.isEmpty) {
      return event;
    }
    final firstException = sentryExceptions.first;

    if (sentryExceptions.length > 1 || firstException.exceptions == null) {
      // If already a list or no child exceptions, no grouping possible/needed.
      return event;
    } else {
      if (_options.groupExceptions) {
        event.exceptions = firstException
            .flatten(groupExceptions: true)
            .reversed
            .toList(growable: false);
      } else {
        event.exceptions = firstException.flatten(groupExceptions: false);
      }
      return event;
    }
  }
}

extension _SentryExceptionFlatten on SentryException {
  List<SentryException> flatten(
      {int? parentId, int id = 0, required bool groupExceptions}) {
    final exceptions = this.exceptions ?? [];

    if (groupExceptions) {
      final newMechanism = mechanism ?? Mechanism(type: "generic");
      newMechanism
        ..type = id > 0 ? "chained" : newMechanism.type
        ..parentId = parentId
        ..exceptionId = id
        ..isExceptionGroup = exceptions.isNotEmpty ? true : null;

      mechanism = newMechanism;
    }

    var all = <SentryException>[];
    all.add(this);

    if (exceptions.isNotEmpty) {
      final parentId = id;
      for (var exception in exceptions) {
        id++;
        final flattenedExceptions = exception.flatten(
            parentId: parentId, id: id, groupExceptions: groupExceptions);
        id = flattenedExceptions.lastOrNull?.mechanism?.exceptionId ?? id;
        all.addAll(flattenedExceptions);
      }
    }
    return all.toList(growable: false);
  }
}
