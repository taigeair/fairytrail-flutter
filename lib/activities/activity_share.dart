import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Share a bucket-list activity via the public web deep link.
///
/// Opens the marketing site dialog at `/bucketlist/?id=…`. Join there tries
/// `fairytrail://activity/{id}` (or the store if the app is not installed).
abstract final class ActivityShare {
  static const _prodWebBase = 'https://www.fairytrail.app';
  static const _stagingWebBase = 'https://staging-fairytrail-web.pages.dev';

  /// Marketing site origin — staging when [EndPoints.isProd] is false.
  static String get webBase =>
      EndPoints.isProd ? _prodWebBase : _stagingWebBase;

  static String get webBucketListBase => '$webBase/bucketlist/';

  static Uri shareUri(int activityId) =>
      Uri.parse(webBucketListBase).replace(queryParameters: {'id': '$activityId'});

  static Future<void> share(
    BuildContext context, {
    required int activityId,
    String? title,
  }) async {
    final url = shareUri(activityId).toString();
    final label = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'Fairytrail activity';
    try {
      await SharePlus.instance.share(
        ShareParams(
          uri: Uri.parse(url),
          title: label,
          subject: label,
        ),
      );
    } catch (e) {
      debugPrint('[ActivityShare] failed: $e');
      if (!context.mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  static Future<void> shareActivity(
    BuildContext context,
    ActivityDto activity,
  ) {
    return share(
      context,
      activityId: activity.id,
      title: activity.displayTitle,
    );
  }
}
