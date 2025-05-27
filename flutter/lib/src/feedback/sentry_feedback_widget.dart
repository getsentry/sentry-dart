// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'sentry_feedback_options.dart';

class SentryFeedbackWidget extends StatefulWidget {
  @internal
  static SentryId? pendingAccociatedEventId;

  static void show(
    BuildContext context, {
    SentryId? associatedEventId,
    SentryAttachment? screenshot,
  }) {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute<SentryFeedbackWidget>(
          builder: (context) => SentryFeedbackWidget(
            associatedEventId: associatedEventId,
            screenshot: screenshot,
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

  @override
  void initState() {
    super.initState();
    _screenshot = widget.screenshot;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.options.title),
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
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          spacing: 8,
                          children: [
                            if (_screenshot != null)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: FutureBuilder<Uint8List>(
                                    future: Future.value(_screenshot!.bytes),
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
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_screenshot != null) {
                                    setState(() {
                                      _screenshot = null;
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
                                        _screenshot =
                                            SentryAttachment.fromByteData(
                                          ByteData.view(imageData.buffer),
                                          pickerFile.name,
                                          contentType: pickerFile.mimeType,
                                        );
                                      });
                                    } catch (e, stackTrace) {
                                      await Sentry.captureException(e,
                                          stackTrace: stackTrace);
                                    }
                                  }
                                },
                                child: _screenshot == null
                                    ? const Text('Add a screenshot')
                                    : const Text('Remove screenshot'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_screenshot == null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              _dismiss(pendingAssociatedEventId: true);
                              SentryScreenshotWidget.showTakeScreenshotButton();
                            },
                            child: const Text('Take a screenshot'),
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
