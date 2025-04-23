import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';

/// A widget that helps track when its child widget is fully displayed in a Flutter application.
///
/// To report that a screen is fully displayed, call:
/// ```dart
/// SentryDisplayWidget.of(context).reportFullDisplay();
/// ```
/// This should be called when your widget is fully rendered and ready to be displayed.
///
/// Example usage:
/// ```dart
/// class MyScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return SentryDisplayWidget(
///       child: MyWidget(),
///     );
///   }
/// }
///
/// /// Widget that executes an expensive operation
/// class MyWidget extends StatefulWidget {
///   const MyWidget({super.key});
///   @override
///   MyWidgetState createState() => MyWidgetState();
/// }
///
/// class MyWidgetState extends State<MyWidget> {
///   static const delayInSeconds = 5;
///
///   @override
///   void initState() {
///     super.initState();
///     _doComplexOperation();
///   }
///
///   /// Attach child spans to the routing transaction
///   /// or the transaction will not be sent to Sentry.
///   Future<void> _doComplexOperation() async {
///     final activeTransaction = Sentry.getSpan();
///     final childSpan = activeTransaction?.startChild(
///       'complex operation',
///       description: 'running a $delayInSeconds seconds operation',
///     );
///
///     await Future.delayed(const Duration(seconds: delayInSeconds));
///
///     // Report that the widget is fully displayed after the complex operation
///     if (mounted) {
///       SentryDisplayWidget.of(context).reportFullyDisplayed();
///     }
///
///     childSpan?.finish();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return const Center(
///       child: CircularProgressIndicator(),
///     );
///   }
/// }
/// ```
class SentryDisplayWidget extends StatefulWidget {
  const SentryDisplayWidget({super.key, required this.child});

  final Widget child;

  static _SentryDisplayWidgetState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SentryDisplayInheritedWidget>()!
        .state;
  }

  @override
  State<SentryDisplayWidget> createState() => _SentryDisplayWidgetState();
}

class _SentryDisplayWidgetState extends State<SentryDisplayWidget> {
  SentryDisplay? _display;

  @override
  void initState() {
    super.initState();
    _display = SentryNavigatorObserver.currentDisplay;
  }

  @override
  Widget build(BuildContext context) {
    return _SentryDisplayInheritedWidget(
      state: this,
      child: widget.child,
    );
  }

  void reportFullyDisplayed() {
    _display?.reportFullyDisplayed();
  }
}

class _SentryDisplayInheritedWidget extends InheritedWidget {
  final _SentryDisplayWidgetState state;

  const _SentryDisplayInheritedWidget({
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SentryDisplayInheritedWidget oldWidget) {
    return state != oldWidget.state;
  }
}
