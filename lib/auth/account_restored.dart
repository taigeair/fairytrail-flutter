import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/app_dialog.dart';
import 'package:flutter/material.dart';

/// RN `alertAccountRestoredIfNeeded` — login cancelled a pending deletion.
///
/// Prefer [maybeShowAccountRestoredAlert] from MainShell after navigation;
/// calling this on a login screen is unsafe because auth remounts the tree.
Future<void> maybeShowAccountRestoredAlert(BuildContext context) async {
  final auth = AuthScope.of(context);
  if (!auth.consumeAccountRestoredAlert()) return;
  if (!context.mounted) return;
  await AppDialog.show(
    context,
    title: 'Account restored',
    message:
        'Your account was scheduled for deletion and has been restored.',
  );
}

/// Friendlier copy when grace period ended and the account was hard-deleted.
String loginErrorText(Object error) {
  final code = serverErrorCode(error);
  if (code == 'account_deleted' ||
      (error is ApiException && error.message == 'account_deleted')) {
    return 'This account has been permanently deleted and can no longer be recovered.';
  }
  return serverErrorText(error);
}
