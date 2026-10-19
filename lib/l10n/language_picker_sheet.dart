import 'dart:async';

import 'package:fairytrail/l10n/locale_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Bottom sheet to pick app language (welcome + profile).
///
/// Opens immediately from the cached/bundled catalog. Remote refresh runs in
/// the background so a slow API never blocks the sheet.
Future<void> showLanguagePickerSheet(BuildContext context) async {
  final controller = LocaleScope.of(context);
  unawaited(controller.refreshCatalogForPicker());

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceOf(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: controller,
        builder: (ctx, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      controller.t('language.title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(ctx),
                      ),
                    ),
                  ),
                  for (final lang in controller.catalog.languages)
                    ListTile(
                      title: Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryOf(ctx),
                        ),
                      ),
                      subtitle: lang.nativeName != lang.name
                          ? Text(
                              lang.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryOf(ctx),
                              ),
                            )
                          : null,
                      trailing: lang.code == controller.languageCode
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () => _onLanguageSelected(
                        hostContext: context,
                        sheetContext: ctx,
                        controller: controller,
                        code: lang.code,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _onLanguageSelected({
  required BuildContext hostContext,
  required BuildContext sheetContext,
  required LocaleController controller,
  required String code,
}) async {
  final needsFetch = await controller.packNeedsRemoteFetch(code);

  // Local (bundled/cached) Hindi/English/Spanish applies immediately.
  await controller.applyLanguageLocally(code);

  if (sheetContext.mounted) {
    Navigator.of(sheetContext).pop();
  }

  if (!needsFetch) {
    // Already up to date — quiet background refresh, no loading UI.
    unawaited(controller.setLanguageCode(code));
    return;
  }

  // One-time: pack missing or version bumped — show updating dialog.
  if (!hostContext.mounted) return;
  showDialog<void>(
    context: hostContext,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogCtx) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  controller.t('language.updating_pack'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryOf(dialogCtx),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  await controller.downloadLanguagePack(code);

  if (hostContext.mounted) {
    Navigator.of(hostContext, rootNavigator: true).pop();
  }
}

/// Compact language control for the welcome screen.
class WelcomeLanguageButton extends StatelessWidget {
  const WelcomeLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = LocaleScope.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showLanguagePickerSheet(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 18,
                color: AppColors.lightTextPrimary.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.currentLanguageLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
