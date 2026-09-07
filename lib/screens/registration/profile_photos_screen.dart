import 'dart:async';
import 'dart:io';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/registration/progress_circles.dart';
import 'package:fairytrail/components/registration/signup_logout_button.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/screens/registration/story_time_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/image_pick_crop.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Step 3: pick photo (uploads in background). Story is a separate optional step.
class ProfilePhotosScreen extends StatefulWidget {
  const ProfilePhotosScreen({super.key, this.reupload = false});

  final bool reupload;

  @override
  State<ProfilePhotosScreen> createState() => _ProfilePhotosScreenState();
}

class _ProfilePhotosScreenState extends State<ProfilePhotosScreen> {
  final _upload = BackgroundPhotoUpload.instance;

  XFile? _photo;
  bool _showsFace = false;
  bool _isContinuing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.reupload) {
      unawaited(track('view_reupload_photo_screen'));
    } else {
      // Signup can resume an interrupted local upload. Forced photo replacement
      // must always start empty so an old rejected/pending image is not reused.
      _restorePendingPhoto();
    }
  }

  void _restorePendingPhoto() {
    final path = _upload.photoPath;
    if (path != null && path.isNotEmpty) {
      _photo = XFile(path);
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_isContinuing) return;
    try {
      final file = await pickAndCropSquareImage(source: source);
      if (file == null || !mounted) return;

      setState(() {
        _photo = file;
        _error = null;
      });

      // Start S3 upload immediately — Continue does not wait for it.
      _upload.start(path: file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not pick image');
    }
  }

  Future<void> _onContinue() async {
    if (_photo == null || !_showsFace || _isContinuing) return;

    setState(() {
      _isContinuing = true;
      _error = null;
    });

    if (widget.reupload) {
      final auth = AuthScope.of(context);
      try {
        final userId = auth.user?.id;
        if (userId != null && userId.isNotEmpty) {
          await LocalStorage.instance.setPhotoUploadCommittedUserId(userId);
        }
        _upload.commit(
          onAttached: () {
            unawaited(auth.refreshMe());
          },
        );
        await auth.markPhotosComplete();
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = serverErrorText(e);
          _isContinuing = false;
        });
      }
      return;
    }

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StoryTimeScreen()));
    if (mounted) setState(() => _isContinuing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final canContinue = _photo != null && _showsFace && !_isContinuing;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.reupload ? 'Update photo' : 'Add your photo'),
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: widget.reupload,
          actions: [
            if (!widget.reupload) SignupLogoutButton(enabled: !_isContinuing),
          ],
        ),
        body: AppSafeArea(
          child: Column(
            children: [
              if (!widget.reupload) ...[
                const ProgressCircles(activeStep: 3),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AppText(
                          _error!,
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                      ],
                      AppCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const AppText(
                              'Add your photo',
                              variant: AppTextVariant.title,
                              fontWeight: FontWeight.w700,
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'A clear face photo helps other travelers recognize you',
                              variant: AppTextVariant.bodySmall,
                              color: muted,
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: GestureDetector(
                                onTap: _isContinuing ? null : _showPickSheet,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: _photo != null
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.45,
                                                )
                                              : theme.colorScheme.outline
                                                    .withValues(alpha: 0.3),
                                          width: _photo != null ? 2 : 1,
                                        ),
                                        image: _photo != null
                                            ? DecorationImage(
                                                image: FileImage(
                                                  File(_photo!.path),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _photo == null
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_a_photo_outlined,
                                                  size: 34,
                                                  color: muted,
                                                ),
                                                const SizedBox(height: 8),
                                                AppText(
                                                  'Tap to add',
                                                  variant:
                                                      AppTextVariant.bodySmall,
                                                  color: muted,
                                                ),
                                              ],
                                            )
                                          : const Align(
                                              alignment: Alignment.bottomRight,
                                              child: Padding(
                                                padding: EdgeInsets.all(8),
                                                child: CircleAvatar(
                                                  radius: 15,
                                                  backgroundColor:
                                                      Colors.black54,
                                                  child: Icon(
                                                    Icons.edit_outlined,
                                                    size: 15,
                                                    color: AppColors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              value: _showsFace,
                              onChanged: _isContinuing
                                  ? null
                                  : (v) =>
                                        setState(() => _showsFace = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const AppText(
                                'My photo clearly shows my face',
                                variant: AppTextVariant.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: AppButton(
                  label: 'Continue',
                  isLoading: _isContinuing,
                  onPressed: canContinue ? _onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
