import 'dart:io';

import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// RN `/main/messages/review` + `/main/modal/review` — ask for a store review.
class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final remote = RemoteConfigScope.of(context);
      if (!remote.isReady) {
        remote.refresh().catchError((Object _) {});
      }
    });
  }

  Future<void> _onReview() async {
    if (_busy) return;
    setState(() => _busy = true);
    await LocalStorage.instance.setReviewLeft();

    try {
      await InAppReview.instance.openStoreListing(appStoreId: '1442011999');
    } catch (e) {
      debugPrint('[WriteReview] openStoreListing failed: $e');
      final uri = Uri.parse(
        Platform.isIOS
            ? 'https://apps.apple.com/app/apple-store/id1442011999'
            : 'https://play.google.com/store/apps/details?id=app.fairytrail.release',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    if (!mounted) return;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onLater() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remote = RemoteConfigScope.of(context);
    final title = remote.reviewTitleText;
    final body = remote.reviewBodyText;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      body,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 20,
                        height: 1.35,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/trailBook/team-sf.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'Rate',
                onPressed: _busy ? null : _onReview,
                isLoading: _busy,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Decline request',
                variant: AppButtonVariant.secondary,
                onPressed: _busy ? null : _onLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
