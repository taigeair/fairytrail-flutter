import 'dart:async';

import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/track/track.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

enum _Phase { select, waitingNative, done }

const _starColor = Color(0xFFFFC107);

/// Custom star-only rating dialog for signup rate step.
///
/// 4–5 stars: native in-app review, then Done. 1–3 stars: Done immediately.
/// Caller stays on the rate screen; this is a modal overlay.
Future<void> showCustomStarRatingDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CustomStarRatingDialog(),
  );
}

class CustomStarRatingDialog extends StatefulWidget {
  const CustomStarRatingDialog({super.key});

  @override
  State<CustomStarRatingDialog> createState() => _CustomStarRatingDialogState();
}

class _CustomStarRatingDialogState extends State<CustomStarRatingDialog> {
  int? _stars;
  _Phase _phase = _Phase.select;

  Future<void> _onStarSelected(int stars) async {
    if (_phase != _Phase.select) return;

    unawaited(HapticsService.light());
    setState(() => _stars = stars);
    unawaited(track('signup_custom_rating_selected', {'stars': stars}));

    if (stars >= 4) {
      setState(() => _phase = _Phase.waitingNative);
      await _requestNativeReview();
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
      return;
    }

    setState(() => _phase = _Phase.done);
  }

  Future<void> _requestNativeReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (e) {
      debugPrint('[CustomStarRating] requestReview failed: $e');
    }
  }

  void _onDone() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final selected = _stars ?? 0;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'How would you rate Fairytrail?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                final filled = star <= selected;
                return Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: _phase == _Phase.select
                        ? () => unawaited(_onStarSelected(star))
                        : null,
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? _starColor
                          : AppColors.textSecondaryOf(context),
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            if (_phase == _Phase.waitingNative) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppText(
                'Opening review…',
                variant: AppTextVariant.caption,
                color: muted,
                textAlign: TextAlign.center,
              ),
            ],
            if (_phase == _Phase.done) ...[
              const SizedBox(height: 20),
              AppButton(label: 'Done', onPressed: _onDone),
            ],
          ],
        ),
      ),
    );
  }
}
