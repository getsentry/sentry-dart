// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';
import 'package:meta/meta.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'sentry_feedback_options.dart';
import 'package:flutter/services.dart';
import 'sentry_logo.dart';
import '../replay/integration.dart';
import '../utils/internal_logger.dart';

/// A form for submitting user feedback to Sentry.
class SentryFeedbackForm extends StatefulWidget {
  SentryFeedbackForm({
    super.key,
    this.associatedEventId,
    this.screenshot,
    @internal Hub? hub,
  })  : assert(associatedEventId != const SentryId.empty()),
        _hub = hub ?? HubAdapter() {
    assert(_hub.options is SentryFlutterOptions,
        'SentryFlutterOptions is required');
    final options = _hub.options as SentryFlutterOptions;
    this.options = options.feedback;
  }

  final SentryId? associatedEventId;
  final Hub _hub;
  final SentryAttachment? screenshot;

  late final SentryFeedbackOptions options;

  @internal
  static SentryId? pendingAssociatedEventId;

  @internal
  @visibleForTesting
  static String? preservedName;

  @internal
  @visibleForTesting
  static String? preservedEmail;

  @internal
  @visibleForTesting
  static String? preservedMessage;

  static void show(
    BuildContext context, {
    SentryId? associatedEventId,
    SentryAttachment? screenshot,
    RouteSettings? routeSettings,
    @internal Hub? hub,
  }) {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute<SentryFeedbackForm>(
          settings: routeSettings,
          builder: (context) => SentryFeedbackForm(
            associatedEventId: associatedEventId,
            screenshot: screenshot,
            hub: hub,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @visibleForTesting
  static void clearPreservedData() {
    SentryFeedbackForm.preservedName = null;
    SentryFeedbackForm.preservedEmail = null;
    SentryFeedbackForm.preservedMessage = null;
  }

  @override
  State<SentryFeedbackForm> createState() => _SentryFeedbackFormState();
}

class _SentryFeedbackFormState extends State<SentryFeedbackForm> {
  // The static preserved-data fields are shared by every instance, so a stale
  // instance (e.g. a success arriving after the user moved on to a newer
  // form) must not overwrite what a newer one did. mounted alone can't tell
  // these apart: it only says whether *this* instance is still around. Each
  // instance gets an increasing generation, and may only write while no newer
  // instance is alive and no newer instance has already written.
  static int _latestGeneration = 0;
  static final Set<int> _liveGenerations = {};
  static int _lastWriterGeneration = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  SentryAttachment? _screenshot;
  Future<Uint8List>? _screenshotFuture;

  bool _isSubmitting = false;
  // Once a submission succeeds, submission-related controls stay disabled
  // for the rest of this instance's lifetime — even if _dismiss() didn't
  // actually close the form (e.g. an app-level PopScope blocking the pop) —
  // so the same, already-accepted feedback can't be sent again. Cancel stays
  // available regardless, as the only way left to close the form.
  bool _isSubmitted = false;
  String? _submitError;

  late final int _generation;

  @override
  void initState() {
    super.initState();

    _generation = ++_latestGeneration;
    _liveGenerations.add(_generation);

    if (widget.options.useSentryUser) {
      _setSentryUserData();
    }
    _restorePreservedData();
    _captureReplay();

    final screenshot = widget.screenshot;
    if (screenshot != null) {
      _screenshot = screenshot;
      _screenshotFuture = Future.value(screenshot.bytes);
    }
  }

  Future<void> _captureReplay() async {
    final integrations = widget._hub.options.integrations;
    final replayIntegration = integrations.firstWhereOrNull(
      (element) => element is ReplayIntegration,
    ) as ReplayIntegration?;
    if (replayIntegration != null) {
      await replayIntegration.captureReplay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: widget.options.resizeToAvoidBottomInset,
      appBar: AppBar(
        title: Text(widget.options.title),
        actions: [
          if (widget.options.showBranding)
            Padding(
              key: const ValueKey('sentry_feedback_branding_logo'),
              padding: const EdgeInsets.only(right: 16.0),
              child: SentryLogo(width: 32),
            ),
        ],
      ),
      body: _buildFormBody(context),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.options.showName) ...[
                      Row(
                        children: [
                          Text(
                            key: const ValueKey('sentry_feedback_name_label'),
                            widget.options.nameLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 4),
                          if (widget.options.isNameRequired)
                            Text(
                              key: const ValueKey(
                                  'sentry_feedback_name_required_label'),
                              widget.options.isRequiredLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        key: const ValueKey('sentry_feedback_name_textfield'),
                        style: Theme.of(context).textTheme.bodyLarge,
                        controller: _nameController,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: widget.options.namePlaceholder,
                        ),
                        keyboardType: TextInputType.text,
                        validator: (String? value) {
                          return _errorText(
                              value, widget.options.isNameRequired);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.options.showEmail) ...[
                      Row(
                        children: [
                          Text(
                            key: const ValueKey('sentry_feedback_email_label'),
                            widget.options.emailLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 4),
                          if (widget.options.isEmailRequired)
                            Text(
                              key: const ValueKey(
                                  'sentry_feedback_email_required_label'),
                              widget.options.isRequiredLabel,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        key: const ValueKey('sentry_feedback_email_textfield'),
                        controller: _emailController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: widget.options.emailPlaceholder,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (String? value) {
                          return _errorText(
                              value, widget.options.isEmailRequired);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Text(
                          key: const ValueKey('sentry_feedback_message_label'),
                          widget.options.messageLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          key: const ValueKey(
                              'sentry_feedback_message_required_label'),
                          widget.options.isRequiredLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const ValueKey('sentry_feedback_message_textfield'),
                      controller: _messageController,
                      style: Theme.of(context).textTheme.bodyLarge,
                      minLines: 5,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: widget.options.messagePlaceholder,
                      ),
                      keyboardType: TextInputType.multiline,
                      validator: (String? value) {
                        return _errorText(value, true);
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(4096),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          if (_screenshotFuture != null) ...[
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: FutureBuilder<Uint8List>(
                                  future: _screenshotFuture,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (snapshot.hasError) {
                                      return const Icon(Icons.error);
                                    }
                                    if (!snapshot.hasData) {
                                      return const SizedBox();
                                    }
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_screenshot != null)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_isSubmitting || _isSubmitted)
                                    ? null
                                    : () async {
                                        setState(() {
                                          _screenshot = null;
                                          _screenshotFuture = null;
                                        });
                                      },
                                child: Text(
                                    key: const ValueKey(
                                        'sentry_feedback_remove_screenshot_button'),
                                    widget.options.removeScreenshotButtonLabel),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_screenshot == null &&
                        widget.options.showCaptureScreenshot)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey(
                              'sentry_feedback_capture_screenshot_button'),
                          onPressed: (_isSubmitting || _isSubmitted)
                              ? null
                              : () async {
                                  _dismiss(preserveFormData: true);
                                  SentryScreenshotWidget
                                      .showTakeScreenshotButton();
                                },
                          child: Text(
                            widget.options.captureScreenshotButtonLabel,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _submitError!,
                      key: const ValueKey('sentry_feedback_submit_error'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('sentry_feedback_submit_button'),
                  onPressed: (_isSubmitting || _isSubmitted) ? null : _submit,
                  child: Text(widget.options.submitButtonLabel),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  key: const ValueKey('sentry_feedback_close_button'),
                  onPressed: () {
                    _dismiss(preserveFormData: false);
                  },
                  child: Text(widget.options.cancelButtonLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _liveGenerations.remove(_generation);
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isSubmitted) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final feedback = SentryFeedback(
      message: _messageController.text,
      contactEmail: _emailController.text,
      name: _nameController.text,
      associatedEventId: widget.associatedEventId,
    );
    Hint? hint;
    if (_screenshot != null) {
      hint = Hint.withScreenshot(_screenshot!);
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    SentryId? sentryId;
    Object? captureException;
    StackTrace? captureStackTrace;
    try {
      sentryId = await _captureFeedback(feedback, hint);
    } catch (exception, stackTrace) {
      captureException = exception;
      captureStackTrace = stackTrace;
    }

    if (sentryId == null || sentryId == const SentryId.empty()) {
      captureException ??= StateError('Feedback was not sent');
      captureStackTrace ??= StackTrace.current;

      // A failed submission leaves the form's data in place for the user to
      // retry, so there's nothing to do if the widget is already gone.
      if (mounted) {
        try {
          widget.options.onSubmitError
              ?.call(feedback, captureException, captureStackTrace);
        } catch (exception, stackTrace) {
          internalLogger.warning(
            'Failed to execute onSubmitError callback',
            error: exception,
            stackTrace: stackTrace,
          );
        }

        setState(() {
          _isSubmitting = false;
          _submitError = widget.options.submitErrorMessageText;
        });
      }
      return;
    }

    // A successful submission always needs to dismiss (its preserved-data
    // clear guards itself against a stale instance via _generation), but the
    // callback and snackbar touch context/UI, so those still require mounted.
    if (mounted) {
      try {
        widget.options.onSubmitSuccess?.call(feedback, sentryId);
      } catch (exception, stackTrace) {
        internalLogger.warning(
          'Failed to execute onSubmitSuccess callback',
          error: exception,
          stackTrace: stackTrace,
        );
      }

      if (widget.options.showSuccessMessage) {
        _showSuccessSnackBar();
      }

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
    }

    _dismiss(preserveFormData: false);
  }

  void _showSuccessSnackBar() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final successColor = widget.options.successColor;
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(successColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: successColor,
        content: Text(
          widget.options.successMessageText,
          style: TextStyle(color: foregroundColor),
        ),
      ),
    );
  }

  String? _errorText(String? value, bool isRequired) {
    if (isRequired && (value == null || value.isEmpty)) {
      return widget.options.validationErrorLabel;
    }
    return null;
  }

  Future<SentryId> _captureFeedback(SentryFeedback feedback, Hint? hint) {
    hint ??= Hint();
    hint.set(TypeCheckHint.isWidgetFeedback, true);
    return widget._hub.captureFeedback(feedback, hint: hint);
  }

  void _dismiss({required bool preserveFormData}) {
    final mayWriteSharedState = _lastWriterGeneration <= _generation &&
        !_liveGenerations.any((generation) => generation > _generation);
    if (mayWriteSharedState) {
      _lastWriterGeneration = _generation;

      SentryFeedbackForm.pendingAssociatedEventId =
          preserveFormData ? widget.associatedEventId : null;

      _writePreservedData(preserveFormData: preserveFormData);
    }

    if (mounted) {
      _closeOwnRoute();
    }
  }

  // Navigator.maybePop() pops whatever is on top, which isn't necessarily this
  // form's route: a callback may have already popped it (so the next one down
  // would go), or another route may have been pushed over it since.
  void _closeOwnRoute() {
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      Navigator.maybePop(context);
    } else if (route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  SentryUser? _getUser() {
    SentryUser? user;
    widget._hub.configureScope((scope) {
      user = scope.user;
    });
    return user;
  }

  void _setSentryUserData() {
    final user = _getUser();
    if (user == null) return;

    final userName = user.name;
    if (userName != null) {
      _nameController.text = userName;
    }
    final userEmail = user.email;
    if (userEmail != null) {
      _emailController.text = userEmail;
    }
  }

  void _restorePreservedData() {
    final preservedName = SentryFeedbackForm.preservedName;
    if (preservedName != null) {
      _nameController.text = preservedName;
    }
    final preservedEmail = SentryFeedbackForm.preservedEmail;
    if (preservedEmail != null) {
      _emailController.text = preservedEmail;
    }
    final preservedMessage = SentryFeedbackForm.preservedMessage;
    if (preservedMessage != null) {
      _messageController.text = preservedMessage;
    }
  }

  void _writePreservedData({required bool preserveFormData}) {
    if (!preserveFormData) {
      SentryFeedbackForm.clearPreservedData();
      return;
    }

    SentryFeedbackForm.preservedName = _nameController.text;
    SentryFeedbackForm.preservedEmail = _emailController.text;
    SentryFeedbackForm.preservedMessage = _messageController.text;
  }
}
