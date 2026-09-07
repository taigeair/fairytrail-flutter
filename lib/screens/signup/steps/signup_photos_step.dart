import 'dart:io';

import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/image_pick_crop.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Step 6 — photo upload (background S3 upload).
class SignupPhotosStep extends StatefulWidget {
  const SignupPhotosStep({
    super.key,
    required this.onContinue,
    this.isLoading = false,
    this.error,
  });

  final VoidCallback onContinue;
  final bool isLoading;
  final String? error;

  @override
  State<SignupPhotosStep> createState() => _SignupPhotosStepState();
}

class _SignupPhotosStepState extends State<SignupPhotosStep> {
  final _upload = BackgroundPhotoUpload.instance;

  XFile? _photo;
  bool _showsFace = false;

  @override
  void initState() {
    super.initState();
    final path = _upload.photoPath;
    if (path != null && path.isNotEmpty) {
      _photo = XFile(path);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (widget.isLoading) return;
    try {
      final file = await pickAndCropSquareImage(source: source);
      if (file == null || !mounted) return;
      setState(() => _photo = file);
      _upload.start(path: file.path);
    } catch (_) {
      // Parent can show a toast if needed; keep local UI simple.
    }
  }

  Future<void> _showPickSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => AppSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final canContinue = _photo != null && _showsFace;

    return SignupStepScaffold(
      step: 6,
      title: 'Add a profile photo',
      subtitle: 'Help others recognize you with a photo',
      canContinue: canContinue,
      isLoading: widget.isLoading,
      onContinue: widget.onContinue,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            if (widget.error != null) ...[
              AppText(
                widget.error!,
                variant: AppTextVariant.bodySmall,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              onTap: widget.isLoading ? null : _showPickSheet,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _photo != null
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.outline,
                    width: _photo != null ? 2 : 1,
                  ),
                  image: _photo != null
                      ? DecorationImage(
                          image: FileImage(File(_photo!.path)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 36,
                            color: muted,
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            'Tap to add',
                            variant: AppTextVariant.bodySmall,
                            color: muted,
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _showsFace,
              onChanged: widget.isLoading
                  ? null
                  : (v) => setState(() => _showsFace = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const AppText(
                'My photo clearly shows my face',
                variant: AppTextVariant.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
