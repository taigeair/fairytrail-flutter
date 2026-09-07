import 'package:fairytrail/screens/trail_book/select_care_option_screen.dart';
import 'package:fairytrail/screens/trail_book/trail_book_screen.dart';
import 'package:flutter/material.dart';

/// Opens Care → postcard send flow (no care pack).
Future<void> openCareFlow(
  BuildContext context, {
  required int profileId,
  required String name,
  String? profilePhotoUrl,
  String path = 'explore',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SelectCareOptionScreen(
        profileId: profileId,
        name: name,
        profilePhotoUrl: profilePhotoUrl,
        path: path,
      ),
    ),
  );
}

Future<void> openTrailBook(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const TrailBookScreen()),
  );
}
