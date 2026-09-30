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
  const SwipePageTransitionsBuilder({this.maxTiltRadians = math.pi});

  /// Tilt when the card is fully off-screen, e.g. `math.pi` for 180°.
  final double maxTiltRadians;

  // How far past the screen edge the card starts/ends.
  static const _overshoot = 1.2;

  @override
  Duration get transitionDuration => const Duration(seconds: 6);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final width = MediaQuery.sizeOf(context).width;

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      child: child,
      builder: (context, child) {
        // Pushing: fly in from the right. Popping: fly out to the left.
        final direction =
            animation.status == AnimationStatus.reverse ? -1.0 : 1.0;
        final away = 1 - Curves.easeOut.transform(animation.value);
        // While another page is swiped on top, sink back like the next card.
        final sink =
            1 - 0.06 * Curves.easeOut.transform(secondaryAnimation.value);

        return Transform.scale(
          scale: sink,
          child: Transform.translate(
            offset: Offset(direction * away * width * _overshoot, 0),
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: direction * away * maxTiltRadians,
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
