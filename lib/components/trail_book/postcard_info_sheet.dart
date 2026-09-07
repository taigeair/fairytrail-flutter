import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Postcard info via the shared [AppDialog] alert.
Future<void> showPostcardInfoSheet(BuildContext context) async {
  const learnMoreUrl = 'https://www.fairytrail.app/terms.html#care';
  final openLearnMore = await AppDialog.confirm(
    context,
    title: 'What is inspire?',
    message:
        'Inspire allows you to send joy to strangers and friends. Make their day.',
    confirmLabel: 'Learn more',
    cancelLabel: 'Got it',
  );
  if (!openLearnMore) return;
  await launchUrl(
    Uri.parse(learnMoreUrl),
    mode: LaunchMode.externalApplication,
  );
}

/// General Trail Book info shown from the Countries section.
Future<void> showTrailBookInfoSheet(BuildContext context) {
  return AppDialog.show(
    context,
    title: 'What is map?',
    message: 'It shows where you\'ve been. If you\'d like to show this on your profile let us know.',
    confirmLabel: 'Got it',
  );
}
