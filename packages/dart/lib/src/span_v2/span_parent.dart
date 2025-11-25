import 'span.dart';

sealed class SpanParent {
  const SpanParent._();

  /// Use the currently active span as parent.
  const factory SpanParent.active() = _ActiveSpanParent;

  /// Use this span as parent regardless of what span is currently active.
  const factory SpanParent.withSpan(Span span) = _ExplicitSpanParent;

  /// Start as a root/segment span.
  const factory SpanParent.none() = _NoSpanParent;
}

class _ActiveSpanParent extends SpanParent {
  const _ActiveSpanParent() : super._();
}

class _ExplicitSpanParent extends SpanParent {
  final Span span;
  const _ExplicitSpanParent(this.span) : super._();
}

class _NoSpanParent extends SpanParent {
  const _NoSpanParent() : super._();
}
