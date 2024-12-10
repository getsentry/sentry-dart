import 'package:gql_link/gql_link.dart';
import 'package:sentry/sentry.dart';

/// Unfortunately, because extractors are looked up via `Type` in map,
/// each exception needs its own extractor.
/// The extractors are quite a few, so we make it easy to add by exposing a
/// method which adds all of the extractors.
extension GqlExctractors on SentryOptions {
  /// Adds various exceptions [ExceptionCauseExtractor] to improve the
  /// visualization of the reported exceptions.
  void addGqlExtractors() {
    addExceptionCauseExtractor(RequestFormatExceptionExtractor());
    addExceptionCauseExtractor(ResponseFormatExceptionExtractor());
    addExceptionCauseExtractor(ContextReadExceptionExtractor());
    addExceptionCauseExtractor(ContextWriteExceptionExtractor());
    addExceptionCauseExtractor(ServerExceptionExtractor());
  }
}

/// [ExceptionCauseExtractor] for [LinkException]s
class LinkExceptionExtractor<T extends LinkException>
    extends ExceptionCauseExtractor<T> {
  @override
  ExceptionCause? cause(T error) {
    return ExceptionCause(error.originalException, error.originalStackTrace);
  }
}

class RequestFormatExceptionExtractor
    extends LinkExceptionExtractor<RequestFormatException> {}

class ResponseFormatExceptionExtractor
    extends LinkExceptionExtractor<ResponseFormatException> {}

class ContextReadExceptionExtractor
    extends LinkExceptionExtractor<ContextReadException> {}

class ContextWriteExceptionExtractor
    extends LinkExceptionExtractor<ContextWriteException> {}

class ServerExceptionExtractor
    extends LinkExceptionExtractor<ServerException> {}
