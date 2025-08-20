// ignore_for_file: library_private_types_in_public_api

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';
import 'package:meta/meta.dart';
import 'sentry_feedback_options.dart';
import 'package:flutter/services.dart';
import 'sentry_logo.dart';
import '../replay/integration.dart';

class SentryFeedbackWidget extends StatefulWidget {
  SentryFeedbackWidget({
    super.key,
    this.associatedEventId,
    this.screenshot,
    @internal Hub? hub,
  })  : assert(associatedEventId != const SentryId.empty()),
        _hub = hub ?? HubAdapter() {
    // ignore: invalid_use_of_internal_member
    assert(_hub.options is SentryFlutterOptions,
        'SentryFlutterOptions is required');
    // ignore: invalid_use_of_internal_member
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
        MaterialPageRoute<SentryFeedbackWidget>(
          settings: routeSettings,
          builder: (context) => SentryFeedbackWidget(
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
    SentryFeedbackWidget.preservedName = null;
    SentryFeedbackWidget.preservedEmail = null;
    SentryFeedbackWidget.preservedMessage = null;
  }

  @override
  _SentryFeedbackWidgetState createState() => _SentryFeedbackWidgetState();
}

class _SentryFeedbackWidgetState extends State<SentryFeedbackWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  SentryAttachment? _screenshot;
  Future<Uint8List>? _screenshotFuture;

  @override
  void initState() {
    super.initState();

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
    // ignore: invalid_use_of_internal_member
    final replayIntegration = widget._hub.options.integrations.firstWhereOrNull(
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
              padding: EdgeInsets.only(right: 16.0),
              child: SentryLogo(width: 32),
            ),
        ],
      ),
      body: Padding(
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
                              key:
                                  const ValueKey('sentry_feedback_email_label'),
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
                          key:
                              const ValueKey('sentry_feedback_email_textfield'),
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
                            key:
                                const ValueKey('sentry_feedback_message_label'),
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
                        key:
                            const ValueKey('sentry_feedback_message_textfield'),
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
                                  onPressed: () async {
                                    setState(() {
                                      _screenshot = null;
                                      _screenshotFuture = null;
                                    });
                                  },
                                  child: Text(
                                      key: const ValueKey(
                                          'sentry_feedback_remove_screenshot_button'),
                                      widget
                                          .options.removeScreenshotButtonLabel),
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
                            onPressed: () async {
                              _dismiss(pendingAssociatedEventId: true);
                              SentryScreenshotWidget.showTakeScreenshotButton();
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('sentry_feedback_submit_button'),
                    onPressed: () async {
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
                      await _captureFeedback(feedback, hint);
                      _dismiss(pendingAssociatedEventId: false);
                    },
                    child: Text(widget.options.submitButtonLabel),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const ValueKey('sentry_feedback_close_button'),
                    onPressed: () {
                      _dismiss(pendingAssociatedEventId: false);
                    },
                    child: Text(widget.options.cancelButtonLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? _errorText(String? value, bool isRequired) {
    if (isRequired && (value == null || value.isEmpty)) {
      return widget.options.validationErrorLabel;
    }
    return null;
  }

  Future<SentryId> _captureFeedback(SentryFeedback feedback, Hint? hint) {
    hint ??= Hint();
    // ignore: invalid_use_of_internal_member
    hint.set(TypeCheckHint.isWidgetFeedback, true);
    return widget._hub.captureFeedback(feedback, hint: hint);
  }

  void _dismiss({required bool pendingAssociatedEventId}) {
    SentryFeedbackWidget.pendingAssociatedEventId =
        pendingAssociatedEventId ? widget.associatedEventId : null;

    _writePreservedData();

    if (mounted) {
      Navigator.maybePop(context);
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
    final preservedName = SentryFeedbackWidget.preservedName;
    if (preservedName != null) {
      _nameController.text = preservedName;
    }
    final preservedEmail = SentryFeedbackWidget.preservedEmail;
    if (preservedEmail != null) {
      _emailController.text = preservedEmail;
    }
    final preservedMessage = SentryFeedbackWidget.preservedMessage;
    if (preservedMessage != null) {
      _messageController.text = preservedMessage;
    }
  }

  void _writePreservedData() {
    if (SentryFeedbackWidget.pendingAssociatedEventId != null) {
      SentryFeedbackWidget.preservedName = _nameController.text;
      SentryFeedbackWidget.preservedEmail = _emailController.text;
      SentryFeedbackWidget.preservedMessage = _messageController.text;
    } else {
      SentryFeedbackWidget.clearPreservedData();
    }
  }
}
