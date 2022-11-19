import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

import 'user_feedback_configuration.dart';
import 'sentry_logo.dart';

class UserFeedbackDialog extends StatefulWidget {
  const UserFeedbackDialog({
    Key? key,
    required this.eventId,
    this.hub,
    this.configuration = const UserFeedbackConfiguration(),
  })  : assert(eventId != const SentryId.empty()),
        super(key: key);

  final SentryId eventId;
  final Hub? hub;
  final UserFeedbackConfiguration configuration;

  @override
  _UserFeedbackDialogState createState() => _UserFeedbackDialogState();
}

class _UserFeedbackDialogState extends State<UserFeedbackDialog> {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController commentController = TextEditingController();

  Hub get _hub => widget.hub ?? HubAdapter();

  @override
  void initState() {
    super.initState();
    // Hacky way to get current user
    _hub.configureScope((scope) {
      nameController.text = scope.user?.name ?? '';
      emailController.text = scope.user?.email ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.configuration.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 4),
            Text(
              widget.configuration.subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const Divider(),
            TextField(
              key: ValueKey('sentry_name_textfield'),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: widget.configuration.labelName,
              ),
              controller: nameController,
              keyboardType: TextInputType.text,
            ),
            SizedBox(height: 8),
            TextField(
              key: ValueKey('sentry_email_textfield'),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: widget.configuration.labelEmail,
              ),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 8),
            TextField(
              key: ValueKey('sentry_comment_textfield'),
              minLines: 5,
              maxLines: null,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: widget.configuration.labelComments,
              ),
              controller: commentController,
              keyboardType: TextInputType.multiline,
            ),
            if (widget.configuration.showPoweredBy) ...[
              SizedBox(height: 8),
              const PoweredBySentryMessage(),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          key: ValueKey('sentry_close_button'),
          onPressed: () => Navigator.pop(context),
          child: Text(widget.configuration.labelClose),
        ),
        ElevatedButton(
          key: ValueKey('sentry_submit_feedback_button'),
          onPressed: _submitUserFeedback,
          child: Text(widget.configuration.labelSubmit),
        ),
      ],
    );
  }

  Future<void> _submitUserFeedback() async {
    final feedback = SentryUserFeedback(
      eventId: widget.eventId,
      comments: commentController.text,
      email: emailController.text,
      name: nameController.text,
    );

    await _hub.captureUserFeedback(feedback);
  }
}
