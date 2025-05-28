// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta/meta.dart';
import 'sentry_feedback_options.dart';
import 'package:flutter/services.dart';
import 'sentry_logo.dart';

class SentryFeedbackWidget extends StatefulWidget {
  @internal
  static SentryId? pendingAccociatedEventId;

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
    this.options = options.feedbackOptions;
  }

  final SentryId? associatedEventId;
  final Hub _hub;
  final SentryAttachment? screenshot;
  late final SentryFeedbackOptions options;

  @override
  _SentryFeedbackWidgetState createState() => _SentryFeedbackWidgetState();
}

class _SentryFeedbackWidgetState extends State<SentryFeedbackWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  SentryAttachment? _screenshot;
  Future<Uint8List>? _screenshotFuture;

  @override
  void initState() {
    super.initState();
    final screenshot = widget.screenshot;
    if (screenshot != null) {
      _screenshot = screenshot;
      _screenshotFuture = Future.value(screenshot.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      if (widget.options.showName)
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
                      if (widget.options.showName) const SizedBox(height: 4),
                      if (widget.options.showName)
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
                      if (widget.options.showName) const SizedBox(height: 16),
                      if (widget.options.showEmail)
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
                      if (widget.options.showEmail) const SizedBox(height: 4),
                      if (widget.options.showEmail)
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
                      if (widget.options.showEmail) const SizedBox(height: 16),
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
                          spacing: 8,
                          children: [
                            if (_screenshotFuture != null)
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
                            if (widget.options.showAddScreenshot)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (_screenshot != null) {
                                      setState(() {
                                        _screenshot = null;
                                        _screenshotFuture = null;
                                      });
                                    } else {
                                      try {
                                        final pickerFile =
                                            await _imagePicker.pickImage(
                                          source: ImageSource.gallery,
                                          requestFullMetadata: false,
                                        );
                                        if (pickerFile == null) {
                                          return;
                                        }
                                        final imageData =
                                            await pickerFile.readAsBytes();
                                        setState(() {
                                          _screenshot = SentryAttachment.fromIntList(
                                            imageData,
                                            pickerFile.name,
                                            contentType: pickerFile.mimeType,
                                          );
                                          _screenshotFuture =
                                              Future.value(imageData);
                                        });
                                      } catch (e, stackTrace) {
                                        await Sentry.captureException(e,
                                            stackTrace: stackTrace);
                                      }
                                    }
                                  },
                                  child: _screenshot == null
                                      ? Text(
                                          key: const ValueKey(
                                              'sentry_feedback_add_screenshot_button'),
                                          widget
                                              .options.addScreenshotButtonLabel)
                                      : Text(
                                          key: const ValueKey(
                                              'sentry_feedback_remove_screenshot_button'),
                                          widget.options
                                              .removeScreenshotButtonLabel),
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
    return widget._hub.captureFeedback(feedback, hint: hint);
  }

  void _dismiss({required bool pendingAssociatedEventId}) {
    SentryFeedbackWidget.pendingAccociatedEventId =
        pendingAssociatedEventId ? widget.associatedEventId : null;
    if (mounted) {
      Navigator.maybePop(context);
    }
  }
}
