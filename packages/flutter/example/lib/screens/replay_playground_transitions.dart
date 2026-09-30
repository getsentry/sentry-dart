import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card-swipe transition: a pushed page is thrown in from the right and a
/// popped page is thrown out to the left, both tilting around their bottom
/// edge. The page underneath shrinks back slightly.
///
/// Built only from [Transform] widgets, which report their transform to the
/// render tree, so Session Replay masks should follow the moving page --
/// unlike [ZoomPageTransitionsBuilder], which scales inside a painter.
class SwipePageTransitionsBuilder extends PageTransitionsBuilder {
  const SwipePageTransitionsBuilder({required this.duration});

  /// How long the swipe takes, both ways.
  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      _SwipeTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
}

class _SwipeTransition extends StatefulWidget {
  const _SwipeTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_SwipeTransition> createState() => _SwipeTransitionState();
}

class _SwipeTransitionState extends State<_SwipeTransition> {
  // How far past the screen edge the card starts/ends, and its tilt there.
  static const _overshoot = 1.2;
  static const _maxTiltRadians = math.pi;

  /// 1 flies in/out on the right, -1 on the left.
  ///
  /// Only flips when the page is fully in or fully out, so a push that's
  /// interrupted by a pop retraces its path instead of jumping to the other
  /// side mid-flight.
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(_SwipeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    final value = widget.animation.value;
    if (status == AnimationStatus.reverse && value == 1.0) {
      _direction = -1; // Popping a page that had landed: out to the left.
    } else if (status == AnimationStatus.forward && value == 0.0) {
      _direction = 1; // Pushing: in from the right.
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedBuilder(
      animation:
          Listenable.merge([widget.animation, widget.secondaryAnimation]),
      child: widget.child,
      builder: (context, child) {
        final away = 1 - Curves.easeOut.transform(widget.animation.value);
        // While another page is swiped on top, sink back like the next card.
        final sink = 1 -
            0.06 * Curves.easeOut.transform(widget.secondaryAnimation.value);

        return Transform.scale(
          scale: sink,
          child: Transform.translate(
            offset: Offset(_direction * away * width * _overshoot, 0),
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: _direction * away * _maxTiltRadians,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// A [MaterialPageRoute] with its own [transitions], overriding the app's
/// [PageTransitionsTheme] for this one page.
///
/// Only this page's own motion changes: the page underneath still animates
/// (via its secondary animation) with its own route's transition.
class TransitionPageRoute<T> extends MaterialPageRoute<T> {
  TransitionPageRoute({
    required super.builder,
    required this.transitions,
    super.settings,
  });

  final PageTransitionsBuilder transitions;

  @override
  Duration get transitionDuration => transitions.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      transitions.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      transitions.buildTransitions(
          this, context, animation, secondaryAnimation, child);
}

/// Runs another [PageTransitionsBuilder]'s transition over [duration], e.g.
/// Flutter's own zoom slowed down so replay mask drift is easy to spot.
class SlowPageTransitionsBuilder extends PageTransitionsBuilder {
  const SlowPageTransitionsBuilder(this.transitions, {required this.duration});

  final PageTransitionsBuilder transitions;
  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      transitions.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      transitions.buildTransitions(
          route, context, animation, secondaryAnimation, child);
}
