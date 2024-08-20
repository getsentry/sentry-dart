// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class FeedbackWidget extends StatefulWidget {
  const FeedbackWidget({
    super.key,
    required this.associatedEventId,
    this.hub,
    this.title = 'Report a Bug',
    this.nameLabel = 'Name',
    this.namePlaceholder = 'Your Name',
    this.emailLabel = 'Email',
    this.emailPlaceholder = 'your.email@example.org',
    this.messageLabel = 'Description',
    this.messagePlaceholder = 'What\'s the bug? What did you expect?',
    this.submitButtonLabel = 'Send Bug Report',
    this.cancelButtonLabel = 'Cancel',
    this.isRequiredLabel = '(required)',
    this.isNameRequired = false,
    this.isEmailRequired = false,
  }) : assert(associatedEventId != const SentryId.empty());

  final SentryId? associatedEventId;
  final Hub? hub;

  final String title;

  final String nameLabel;
  final String namePlaceholder;
  final String emailLabel;
  final String emailPlaceholder;
  final String messageLabel;
  final String messagePlaceholder;

  final String submitButtonLabel;
  final String cancelButtonLabel;

  final String isRequiredLabel;

  final bool isNameRequired;
  final bool isEmailRequired;

  @override
  _FeedbackWidgetState createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends State<FeedbackWidget> {

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? _name;
  String? _email;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                            key: const ValueKey('sentry_feedback_name_required_label'),
                            widget.isRequiredLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('sentry_feedback_name_textfield'),
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: widget.namePlaceholder,
                        errorText: _errorText(_name),
                      ),
                      controller: _nameController,
                      keyboardType: TextInputType.text,
                      onChanged: (text) => setState(() => _name = text ),
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
                            key: const ValueKey('sentry_feedback_email_required_label'),
                            widget.isRequiredLabel,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('sentry_feedback_email_textfield'),
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: widget.emailPlaceholder,
                        errorText: _errorText(_email),
                      ),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (text) => setState(() => _email = text ),
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
                          key: const ValueKey('sentry_feedback_message_required_label'),
                          widget.isRequiredLabel,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey('sentry_feedback_message_textfield'),
                      style: Theme.of(context).textTheme.bodyLarge,
                      minLines: 5,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: widget.messagePlaceholder,
                        errorText: _errorText(_message),
                      ),
                      controller: _messageController,
                      keyboardType: TextInputType.multiline,
                      onChanged: (text) => setState(() => _message = text ),
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

                      if (_name == null || _email == null || _message == null) {
                        setState(() {
                          _name ??= '';
                          _email ??= '';
                          _message ??= '';
                        });
                      }

                      if (!_valid(_name) || !_valid(_email) || !_valid(_message)) {
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

  Future<void> _captureFeedback(SentryFeedback feedback) {
    // ignore: deprecated_member_use
    return (widget.hub ?? HubAdapter()).captureFeedback(feedback);
  }

  String? _errorText(String? text) {
    if (text != null && text.isEmpty) {
      return 'Can\'t be empty';
    } else {
      return null;
    }
  }

  bool _valid(String? text) {
    return text != null && text.isNotEmpty;
  }
}
