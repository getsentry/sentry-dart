// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import '../../sentry_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class SentryFeedbackWidget extends StatefulWidget {
  SentryFeedbackWidget({
    super.key,
    this.associatedEventId,
    Hub? hub,
    String? title,
    String? nameLabel,
    String? namePlaceholder,
    String? emailLabel,
    String? emailPlaceholder,
    String? messageLabel,
    String? messagePlaceholder,
    String? submitButtonLabel,
    String? cancelButtonLabel,
    String? validationErrorLabel,
    String? isRequiredLabel,
    String? successMessageText,
    bool? isNameRequired,
    bool? showName,
    bool? isEmailRequired = false,
    bool? showEmail = true,
    bool? useSentryUser = true,
    bool? showBranding = true,
    this.screenshot,
  })  : assert(associatedEventId != const SentryId.empty()),
        _hub = hub ?? HubAdapter() {
    // ignore: invalid_use_of_internal_member
    assert(_hub.options is SentryFlutterOptions,
        'SentryFlutterOptions is required');
    // ignore: invalid_use_of_internal_member
    final options = _hub.options as SentryFlutterOptions;
    final feedbackOptions = options.feedbackOptions;

    this.title = title ?? feedbackOptions.title;
    this.nameLabel = nameLabel ?? feedbackOptions.nameLabel;
    this.namePlaceholder = namePlaceholder ?? feedbackOptions.namePlaceholder;
    this.emailLabel = emailLabel ?? feedbackOptions.emailLabel;
    this.emailPlaceholder =
        emailPlaceholder ?? feedbackOptions.emailPlaceholder;
    this.messageLabel = messageLabel ?? feedbackOptions.messageLabel;
    this.messagePlaceholder =
        messagePlaceholder ?? feedbackOptions.messagePlaceholder;
    this.submitButtonLabel =
        submitButtonLabel ?? feedbackOptions.submitButtonLabel;
    this.cancelButtonLabel =
        cancelButtonLabel ?? feedbackOptions.cancelButtonLabel;
    this.validationErrorLabel =
        validationErrorLabel ?? feedbackOptions.validationErrorLabel;
    this.isRequiredLabel = isRequiredLabel ?? feedbackOptions.isRequiredLabel;
    this.successMessageText =
        successMessageText ?? feedbackOptions.successMessageText;
    this.isNameRequired = isNameRequired ?? feedbackOptions.isNameRequired;
    this.showName = showName ?? feedbackOptions.showName;
    this.isEmailRequired = isEmailRequired ?? feedbackOptions.isEmailRequired;
    this.showEmail = showEmail ?? feedbackOptions.showEmail;
    this.useSentryUser = useSentryUser ?? feedbackOptions.useSentryUser;
    this.showBranding = showBranding ?? feedbackOptions.showBranding;
  }

  final SentryId? associatedEventId;
  final Hub _hub;
  final SentryAttachment? screenshot;

  late final String title;

  late final String nameLabel;
  late final String namePlaceholder;
  late final String emailLabel;
  late final String emailPlaceholder;
  late final String messageLabel;
  late final String messagePlaceholder;

  late final String submitButtonLabel;
  late final String cancelButtonLabel;
  late final String validationErrorLabel;

  late final String isRequiredLabel;
  late final String successMessageText;

  late final bool isNameRequired;
  late final bool showName;

  late final bool isEmailRequired;
  late final bool showEmail;

  late final bool useSentryUser;
  late final bool showBranding;

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
        title: Text(widget.title),
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
                            widget.nameLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 4),
                          if (widget.isNameRequired)
                            Text(
                              key: const ValueKey(
                                  'sentry_feedback_name_required_label'),
                              widget.isRequiredLabel,
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
                          hintText: widget.namePlaceholder,
                        ),
                        keyboardType: TextInputType.text,
                        validator: (String? value) {
                          return _errorText(value, widget.isNameRequired);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            key: const ValueKey('sentry_feedback_email_label'),
                            widget.emailLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 4),
                          if (widget.isEmailRequired)
                            Text(
                              key: const ValueKey(
                                  'sentry_feedback_email_required_label'),
                              widget.isRequiredLabel,
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
                          hintText: widget.emailPlaceholder,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (String? value) {
                          return _errorText(value, widget.isEmailRequired);
                        },
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            key:
                                const ValueKey('sentry_feedback_message_label'),
                            widget.messageLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            key: const ValueKey(
                                'sentry_feedback_message_required_label'),
                            widget.isRequiredLabel,
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
                          hintText: widget.messagePlaceholder,
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
                                    ? const Text('Add Screenshot')
                                    : const Text('Remove Screenshot'),
                              ),
                            ),
                          ],
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
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        await Navigator.maybePop(context);
                      }
                    },
                    child: Text(widget.submitButtonLabel),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const ValueKey('sentry_feedback_close_button'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(widget.cancelButtonLabel),
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
      return widget.validationErrorLabel;
    }
    return null;
  }

  Future<SentryId> _captureFeedback(SentryFeedback feedback, Hint? hint) {
    return widget._hub.captureFeedback(feedback, hint: hint);
  }
}
