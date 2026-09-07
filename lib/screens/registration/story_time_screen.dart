import 'dart:async';

import 'package:fairytrail/api/update_user_data.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/registration/progress_circles.dart';
import 'package:fairytrail/components/registration/signup_logout_button.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Optional "Most adventurous experience" step — can be skipped.
class StoryTimeScreen extends StatefulWidget {
  const StoryTimeScreen({super.key});

  @override
  State<StoryTimeScreen> createState() => _StoryTimeScreenState();
}

class _StoryTimeScreenState extends State<StoryTimeScreen> {
  final _storyController = TextEditingController();
  final _upload = BackgroundPhotoUpload.instance;

  bool _isFinishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreStory();
  }

  Future<void> _restoreStory() async {
    final data = await LocalStorage.instance.getRegistrationData();
    if (!mounted || data == null) return;
    final story = data['storyTime'] as String?;
    if (story != null && story.isNotEmpty) {
      _storyController.text = story;
    }
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  Future<void> _persistStory() async {
    final data = Map<String, dynamic>.from(
      await LocalStorage.instance.getRegistrationData() ?? {},
    );
    data['storyTime'] = _storyController.text.trim();
    await LocalStorage.instance.setRegistrationData(data);
  }

  Future<void> _finish({required bool saveStory}) async {
    if (_isFinishing) return;

    setState(() {
      _isFinishing = true;
      _error = null;
    });

    final auth = AuthScope.of(context);

    try {
      final userId = auth.user?.id;
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.instance.setPhotoUploadCommittedUserId(userId);
      }

      final story = _storyController.text.trim();
      if (saveStory && story.isNotEmpty) {
        await _persistStory();
        unawaited(_saveStoryIfPossible(story));
      }

      _upload.commit(
        onAttached: () {
          unawaited(auth.refreshMe());
        },
      );

      await auth.markPhotosComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _isFinishing = false;
      });
    }
  }

  Future<void> _saveStoryIfPossible(String story) async {
    final draft = await LocalStorage.instance.getRegistrationData();
    if (!mounted) return;
    final user = AuthScope.of(context).user;
    final name = (draft?['name'] as String?)?.trim().isNotEmpty == true
        ? (draft!['name'] as String).trim()
        : (user?.name ?? '');
    final mobility = (draft?['mobility'] as String?) ?? '';
    if (name.isEmpty || mobility.isEmpty) return;

    final age = (draft?['age'] as num?)?.toInt();
    try {
      await updateUserStory(
        name: name,
        mobility: mobility,
        storyTime: story,
        age: age,
      );
    } catch (_) {
      // Story can be edited later in profile.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Almost done'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [SignupLogoutButton(enabled: !_isFinishing)],
      ),
      body: AppSafeArea(
        child: Column(
          children: [
            const ProgressCircles(activeStep: 3),
            const SizedBox(height: 8),
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
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: AppText(
                                  'Most adventurous experience',
                                  variant: AppTextVariant.title,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: AppText(
                                  'Optional',
                                  variant: AppTextVariant.caption,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppText(
                            'Share a short story travelers will see on your profile.',
                            variant: AppTextVariant.bodySmall,
                            color: muted,
                          ),
                          const SizedBox(height: 12),
                          AppTextArea(
                            controller: _storyController,
                            hint:
                                'e.g. Hitchhiked across Iceland with strangers ...',
                            minLines: 4,
                            maxLines: 6,
                            maxLength: 260,
                            textCapitalization: TextCapitalization.sentences,
                            enabled: !_isFinishing,
                            onChanged: (_) => _persistStory(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  AppButton(
                    label: 'Continue',
                    isLoading: _isFinishing,
                    onPressed: _isFinishing
                        ? null
                        : () => _finish(saveStory: true),
                  ),
                  const SizedBox(height: 4),
                  AppButton(
                    label: 'Skip for now',
                    variant: AppButtonVariant.text,
                    onPressed: _isFinishing
                        ? null
                        : () => _finish(saveStory: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
