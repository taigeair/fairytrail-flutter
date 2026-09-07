import 'dart:async';
import 'dart:io';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Fullscreen blocker when signup photo failed to finish uploading.
class FinishPhotoUploadScreen extends StatefulWidget {
  const FinishPhotoUploadScreen({super.key});

  @override
  State<FinishPhotoUploadScreen> createState() =>
      _FinishPhotoUploadScreenState();
}

class _FinishPhotoUploadScreenState extends State<FinishPhotoUploadScreen> {
  final _upload = BackgroundPhotoUpload.instance;

  @override
  void initState() {
    super.initState();
    unawaited(track('view_finish_photo_upload_blocker'));
    _upload.addListener(_onUploadChanged);
  }

  @override
  void dispose() {
    _upload.removeListener(_onUploadChanged);
    super.dispose();
  }

  Future<void> _onUploadChanged() async {
    if (!mounted) return;
    setState(() {});

    if (_upload.status == BackgroundPhotoUploadStatus.done) {
      try {
        await AuthScope.of(context).refreshMe();
      } catch (_) {}
      _upload.acknowledgeCompleted();
    }
  }

  void _onRetry() {
    unawaited(track('finish_photo_upload_blocker_retry'));
    _upload.retry();
  }

  Future<void> _onPickDifferent() async {
    unawaited(track('finish_photo_upload_blocker_repick'));
    await AuthScope.of(context).beginPhotoReupload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _upload.status;
    final isFailed = status == BackgroundPhotoUploadStatus.failed;
    final photoPath = _upload.photoPath;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              AppText(
                isFailed
                    ? "Your photo didn't finish uploading"
                    : 'Uploading your photo…',
                variant: AppTextVariant.title,
                textAlign: TextAlign.center,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 28),
              if (photoPath != null)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(photoPath),
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Container(
                          width: 180,
                          height: 180,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: muted,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    if (!isFailed)
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
              AppText(
                isFailed
                    ? 'Your profile needs a photo before others can see you. Please try again.'
                    : 'Hang tight — this should only take a moment.',
                variant: AppTextVariant.bodySmall,
                textAlign: TextAlign.center,
                color: muted,
              ),
              const SizedBox(height: 28),
              if (isFailed) ...[
                AppButton(
                  label: 'Retry upload',
                  onPressed: _onRetry,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Choose a different photo',
                  variant: AppButtonVariant.text,
                  isExpanded: false,
                  onPressed: _onPickDifferent,
                ),
              ] else
                const CircularProgressIndicator(strokeWidth: 2),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
