import 'package:fairytrail/screens/registration/profile_photos_screen.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when connect fails with `photo_issue` — asks user to replace their photo.
Future<void> showPhotoIssueSheet(BuildContext context) async {
  const standardsUrl = 'https://www.fairytrail.app/support.html#standards';
  final updatePhoto = await AppDialog.confirm(
    context,
    title: "Let's update your photos",
    message:
        "To help keep Fairytrail safe and authentic, we ask for a clear face photo.",
    confirmLabel: 'Choose new photo',
    cancelLabel: 'View guidelines',
    barrierDismissible: false,
  );
  if (!context.mounted) return;
  if (updatePhoto) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProfilePhotosScreen(reupload: true),
      ),
    );
    return;
  }
  await launchUrl(
    Uri.parse(standardsUrl),
    mode: LaunchMode.externalApplication,
  );
}
