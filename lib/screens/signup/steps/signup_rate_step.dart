import 'dart:async';

import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/signup_faces.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/review/custom_star_rating_dialog.dart';
import 'package:fairytrail/review/review_prompt.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

/// Step 10 — rate us with social proof reviews.
///
/// When [RemoteConfigController.showCustomRatingPopup] is true, Continue opens
/// a custom star dialog (optional native review for 4–5 stars) before advancing.
/// Otherwise keeps the legacy auto system prompt + 3s lock.
///
/// Also warms People discovery (prefs → matches → prefetch) while the user
/// reads this screen — location is already on the server.
class SignupRateStep extends StatefulWidget {
  const SignupRateStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<SignupRateStep> createState() => _SignupRateStepState();
}

class _SignupRateStepState extends State<SignupRateStep> {
  static const _reviews = <(String, String, int)>[
    (
      'Kristine · Solo traveler',
      'Found a travel buddy in Madeira within a day. Love this beautiful community!',
      2,
    ),
    (
      'Toby · Digital nomad',
      'Best app for meeting remote workers. Filters are solid for finding fellow travelers with similar goals.',
      1,
    ),
    (
      'Mandy · World citizen',
      'Really big international community. Met a few people on it. One who I\'ve done three trips with!',
      3,
    ),
  ];

  static const _lockSeconds = 3;

  Timer? _countdownTimer;
  Timer? _reviewTimer;
  int _secondsLeft = _lockSeconds;
  bool _busy = false;

  bool get _useCustomPopup =>
      RemoteConfigScope.of(context).showCustomRatingPopup;

  bool get _canContinue =>
      _useCustomPopup ? !_busy : _secondsLeft <= 0 && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final meta = AuthScope.of(context).profileMeta;
      ExploreWarmPrefetch.instance.start(profileMeta: meta);
      _startLegacyTimersIfNeeded();
    });
  }

  void _startLegacyTimersIfNeeded() {
    if (!mounted || _useCustomPopup) return;

    _reviewTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_promptReview());
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _reviewTimer?.cancel();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;

    if (_useCustomPopup) {
      setState(() => _busy = true);

      await showCustomStarRatingDialog(context);

      if (!mounted) return;

      ReviewPrompt.cancelPending();
      await LocalStorage.instance.setReviewLeft();

      if (!mounted) return;
      widget.onContinue();
      return;
    }

    setState(() => _busy = true);
    _countdownTimer?.cancel();
    _reviewTimer?.cancel();

    ReviewPrompt.cancelPending();
    await LocalStorage.instance.setReviewLeft();

    if (!mounted) return;
    widget.onContinue();
  }

  Future<void> _promptReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (e) {
      debugPrint('[SignupRate] requestReview failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    return SignupStepScaffold(
      step: 10,
      title: 'It starts with being kind',
      continueLabel: 'Continue',
      subtitle: 'Let\'s make Fairytrail a great place',
      canContinue: _canContinue,
      isLoading: _busy,
      onContinue: () => unawaited(_onContinue()),
      bottomHelper: AppText(
        'Ratings can help others discover our community',
        variant: AppTextVariant.bodySmall,
        color: AppColors.textSecondaryOf(context),
        textAlign: TextAlign.center,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _FaceStrip(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (_) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC107),
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Built for nomads & solo travelers',
                    variant: AppTextVariant.bodySmall,
                    textAlign: TextAlign.center,
                    color: muted,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _reviews.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ReviewCard(
                      name: _reviews[i].$1,
                      quote: _reviews[i].$2,
                      photoAsset: SignupFaces.all[_reviews[i].$3],
                      photoSize: 70,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaceStrip extends StatelessWidget {
  const _FaceStrip();

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    const overlap = 12.0;
    final photos = SignupFaces.all
        .where(
          (photo) =>
              !photo.endsWith('/face_1.jpg') && !photo.endsWith('/face_2.jpg'),
        )
        .toList();
    final width = size + (photos.length - 1) * (size - overlap);

    return SizedBox(
      height: size + 2,
      width: width,
      child: Stack(
        children: [
          for (var i = 0; i < photos.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: AppColors.lightGray,
                    child: Image.asset(
                      photos[i],
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.name,
    required this.quote,
    required this.photoAsset,
    required this.photoSize,
  });

  final String name;
  final String quote;
  final String photoAsset;
  final double photoSize;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return AppCard(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: photoSize,
            height: photoSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: ColoredBox(
                color: AppColors.lightGray,
                child: Image.asset(
                  photoAsset,
                  fit: BoxFit.cover,
                  width: photoSize,
                  height: photoSize,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (_) => const Icon(
                Icons.star_rounded,
                size: 16,
                color: Color(0xFFFFC107),
              ),
            ),
          ),
          const SizedBox(height: 6),
          AppText(
            name,
            variant: AppTextVariant.caption,
            color: muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          AppText(
            quote,
            variant: AppTextVariant.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
