import 'package:fairytrail/config/daily_limit_copy_config.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Gold: "View more tomorrow" (RN explore/limit-reached).
/// Free/silver/gated: upgrade prompt (RN upgrade modal reason=limit_reached).
class ExploreDailyLimitView extends StatelessWidget {
  const ExploreDailyLimitView({
    super.key,
    required this.isGold,
    this.onUpgrade,
    this.onExploreActivities,
    this.bottomInset = 0,
  });

  final bool isGold;
  final VoidCallback? onUpgrade;
  final VoidCallback? onExploreActivities;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    final copy =
        RemoteConfigScope.maybeOf(context)?.dailyLimitCopy ??
        DailyLimitCopyConfig.defaults;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 16 + bottomInset),
          child: Column(
            children: [
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      copy.title,
                      variant: AppTextVariant.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                    const SizedBox(height: 12),
                    AppText(
                      copy.subtitleFor(isGold: isGold),
                      variant: AppTextVariant.body,
                      fontSize: 20,
                      color: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _DailyLimitImage(imageUrl: copy.imageUrl),
              const Spacer(),
              if (!isGold && onUpgrade != null) ...[
                AppButton(label: copy.upgradeButton, onPressed: onUpgrade),
                if (onExploreActivities != null) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: copy.activitiesButton,
                    variant: AppButtonVariant.secondary,
                    onPressed: onExploreActivities,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLimitImage extends StatelessWidget {
  const _DailyLimitImage({this.imageUrl});

  final String? imageUrl;

  static const _size = 222.0;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return AppCachedImage(
        url: imageUrl!,
        width: _size,
        height: _size,
        fit: BoxFit.contain,
        showPlaceholderUnderlay: false,
      );
    }

    return Image.asset(
      DailyLimitCopyConfig.fallbackAsset,
      width: _size,
      height: _size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Mountain',
    );
  }
}

/// RN `/main/explore/unapproved`.
class ExploreUnapprovedView extends StatelessWidget {
  const ExploreUnapprovedView({
    super.key,
    this.reason,
    this.onEditPhoto,
    this.bottomInset = 0,
  });

  final String? reason;
  final VoidCallback? onEditPhoto;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 40, 24, 16 + bottomInset),
      child: Column(
        children: [
          const Spacer(),
          const AppText(
            "You're almost in!",
            variant: AppTextVariant.title,
            textAlign: TextAlign.center,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
          const SizedBox(height: 20),
          AppText(
            reason != null && reason!.isNotEmpty
                ? 'We noticed your profile $reason. Edit your profile and photos to ensure they are appropriate.'
                : 'Edit your profile and photos to ensure they are appropriate.',
            variant: AppTextVariant.body,
            textAlign: TextAlign.center,
            fontSize: 18,
            color: muted,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('mailto:team@fairytrail.app'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text.rich(
              TextSpan(
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 18, color: muted),
                children: const [
                  TextSpan(text: 'If you require assistance, contact '),
                  TextSpan(
                    text: 'team@fairytrail.app',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Spacer(),
          if (onEditPhoto != null)
            AppButton(label: 'Update photo', onPressed: onEditPhoto),
        ],
      ),
    );
  }
}

/// RN no-more-profiles empty deck.
class ExploreNoMoreProfilesView extends StatelessWidget {
  const ExploreNoMoreProfilesView({
    super.key,
    required this.onModifySearch,
    this.bottomInset = 0,
  });

  final VoidCallback onModifySearch;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.fromLTRB(28, 24, 28, 16 + bottomInset),
      child: Column(
        children: [
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  "That's everyone but thousands of travelers join daily!",
                  variant: AppTextVariant.title,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
                const SizedBox(height: 12),
                AppText(
                  'Try widening your filters',
                  variant: AppTextVariant.body,
                  fontSize: 20,
                  color: muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Icon(
            Icons.travel_explore_outlined,
            size: 88,
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          const Spacer(),
          AppButton(label: 'Change filters', onPressed: onModifySearch),
        ],
      ),
    );
  }
}
