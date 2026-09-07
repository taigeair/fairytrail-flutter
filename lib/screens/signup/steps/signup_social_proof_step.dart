import 'dart:ui';

import 'package:fairytrail/config/signup_faces.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 5 — social proof before photo upload.
class SignupSocialProofStep extends StatelessWidget {
  const SignupSocialProofStep({
    super.key,
    required this.onContinue,
    required this.travelStyleLabel,
  });

  final VoidCallback onContinue;
  final String travelStyleLabel;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return SignupStepScaffold(
      step: 5,
      title: 'You’re in good company',
      continueLabel: 'Continue',
      onContinue: onContinue,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            const Spacer(),
            _ModernProofCard(travelStyleLabel: travelStyleLabel),
            const SizedBox(height: 40),
            // Wrap(
            //   spacing: 8,
            //   runSpacing: 8,
            //   alignment: WrapAlignment.center,
            //   children: const [
            //     _TrustPill(
            //       icon: Icons.lock_outline_rounded,
            //       label: 'Private by default',
            //     ),
            //     _TrustPill(
            //       icon: Icons.favorite_outline_rounded,
            //       label: 'Built for travelers',
            //     ),
            //     _TrustPill(
            //       icon: Icons.handshake_outlined,
            //       label: 'Meet with intent',
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 14),
            // AppText(
            //   'Join travelers who already share your interests — buddies, friendships, and adventures wait ahead.',
            //   variant: AppTextVariant.caption,
            //   textAlign: TextAlign.center,
            //   color: muted,
            // ),
            const SizedBox(height: 20),
            AppText(
              'Let’s finish setting up your profile!',
              variant: AppTextVariant.bodySmall,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}

class _ModernProofCard extends StatelessWidget {
  const _ModernProofCard({required this.travelStyleLabel});

  final String travelStyleLabel;

  static const _mediaHeight = 128.0;
  static const _avatarOverlap = 30.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        boxShadow: [
          ...AppShadows.of(context),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            SizedBox(
              height: _mediaHeight + _avatarOverlap,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _mediaHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/signup/travel-bg2.jpg',
                          fit: BoxFit.cover,
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                          child: const SizedBox.expand(),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.28),
                                Colors.black.withValues(alpha: 0.10),
                                Colors.white,
                              ],
                              stops: const [0, 0.5, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 4),
                                AppText(
                                  'Verified profiles',
                                  variant: AppTextVariant.caption,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(child: _AvatarCluster()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                children: [
                  const AppText(
                    'Over 5 million',
                    variant: AppTextVariant.headline,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w800,
                    fontSize: 42,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    'connections made',
                    variant: AppTextVariant.title,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary.withValues(alpha: 0.85),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppText(
                    travelStyleLabel,
                    variant: AppTextVariant.body,
                    textAlign: TextAlign.center,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary.withValues(alpha: 0.78),
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

class _AvatarCluster extends StatelessWidget {
  const _AvatarCluster();

  @override
  Widget build(BuildContext context) {
    const photos = SignupFaces.all;
    const size = 48.0;
    const borderWidth = 3.0;
    const overlap = 14.0;
    const stride = size - overlap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCount = constraints.maxWidth < size
            ? 0
            : ((constraints.maxWidth - size) / stride).floor() + 1;
        final faceCount = visibleCount.clamp(0, photos.length);
        final width = faceCount == 0 ? 0.0 : size + (faceCount - 1) * stride;

        return SizedBox(
          height: size + 4,
          width: width,
          child: Stack(
            children: [
              for (var i = 0; i < faceCount; i++)
                Positioned(
                  left: i * stride,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: borderWidth,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.lightGray),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
