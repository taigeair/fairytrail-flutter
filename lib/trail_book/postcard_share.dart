import 'dart:io';
import 'dart:ui' as ui;

import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Capture a postcard [RepaintBoundary] and share it as an image.
abstract final class PostcardShare {
  static Future<void> shareCapturedPostcard(
    BuildContext context, {
    required GlobalKey boundaryKey,
  }) async {
    try {
      final file = await _capture(boundaryKey);
      final postcard = XFile(file.path, mimeType: 'image/png');

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [postcard],
          title: 'A postcard from Fairytrail',
          subject: 'A postcard from Fairytrail',
          previewThumbnail: postcard,
        ),
      );

      if (!context.mounted) return;
      if (result.status == ShareResultStatus.success) {
        // Optional soft confirmation — many platforms show their own UI.
      }
    } catch (e) {
      debugPrint('[PostcardShare] failed: $e');
      if (!context.mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  static Future<void> saveCapturedPostcard(
    BuildContext context, {
    required GlobalKey boundaryKey,
  }) async {
    try {
      final file = await _capture(boundaryKey);
      await Gal.putImage(file.path);
      if (!context.mounted) return;
      AppToast.show(context, message: 'Postcard saved to Photos');
    } on GalException catch (e) {
      debugPrint('[PostcardShare] save failed: $e');
      if (!context.mounted) return;
      final message = switch (e.type) {
        GalExceptionType.accessDenied =>
          'Allow photo access to save postcards to Photos.',
        GalExceptionType.notEnoughSpace =>
          'Not enough storage space to save this postcard.',
        GalExceptionType.notSupportedFormat =>
          'This postcard could not be saved as an image.',
        GalExceptionType.unexpected =>
          'Could not save the postcard. Please try again.',
      };
      AppToast.show(context, message: message);
    } catch (e) {
      debugPrint('[PostcardShare] save failed: $e');
      if (!context.mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  static Future<File> _capture(GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Postcard preview not ready');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not capture postcard');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/fairytrail_postcard_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }
}
