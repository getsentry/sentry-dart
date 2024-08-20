// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryFeedbackWidget extends StatefulWidget {
  SentryFeedbackWidget({
    super.key,
    this.associatedEventId,
    Hub? hub,
    this.title = 'Report a Bug',
    this.nameLabel = 'Name',
    this.namePlaceholder = 'Your Name',
    this.emailLabel = 'Email',
    this.emailPlaceholder = 'your.email@example.org',
    this.messageLabel = 'Description',
    this.messagePlaceholder = 'What\'s the bug? What did you expect?',
    this.submitButtonLabel = 'Send Bug Report',
    this.cancelButtonLabel = 'Cancel',
    this.validationErrorLabel = 'Can\'t be empty',
    this.isRequiredLabel = '(required)',
    this.isNameRequired = false,
    this.isEmailRequired = false,
  })  : assert(associatedEventId != const SentryId.empty()),
        _hub = hub ?? HubAdapter();

  final SentryId? associatedEventId;
  final Hub _hub;

  final String title;

  final String nameLabel;
  final String namePlaceholder;
  final String emailLabel;
  final String emailPlaceholder;
  final String messageLabel;
  final String messagePlaceholder;

  final String submitButtonLabel;
  final String cancelButtonLabel;
  final String validationErrorLabel;

  final String isRequiredLabel;

  final bool isNameRequired;
  final bool isEmailRequired;

  @override
  _SentryFeedbackWidgetState createState() => _SentryFeedbackWidgetState();
}

class _SentryFeedbackWidgetState extends State<SentryFeedbackWidget> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _name;
  String? _email;
  String? _message;

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
                          key: const ValueKey('sentry_feedback_message_label'),
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
                      key: const ValueKey('sentry_feedback_message_textfield'),
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
                  ],
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                      await _captureFeedback(feedback);
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context);
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

  Future<SentryId> _captureFeedback(SentryFeedback feedback) {
    return widget._hub.captureFeedback(feedback);
  }
}
