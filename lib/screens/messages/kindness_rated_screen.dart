import 'package:fairytrail/screens/messages/kindness_rated_asset.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// RN `customKindnessRateModal` — postcard-only thank-you after a positive rating.
class KindnessRatedScreen extends StatelessWidget {
  const KindnessRatedScreen({
    super.key,
    required this.profileId,
    required this.name,
    this.profilePhotoUrl,
    this.senderProfileType,
    this.receiverProfileType,
  });

  final int profileId;
  final String name;
  final String? profilePhotoUrl;
  final String? senderProfileType;
  final String? receiverProfileType;

  String get _firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'them';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final imageAsset = kindnessRatedAsset(
      senderProfileType: senderProfileType,
      receiverProfileType: receiverProfileType,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kindness'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                imageAsset,
                width: 200,
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              AppText(
                'You gave $_firstName a kindness point!',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              AppText(
                'Want to write them a postcard also?',
                variant: AppTextVariant.body,
                color: AppColors.textSecondaryOf(context),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'Write a postcard',
                onPressed: () async {
                  Navigator.of(context).pop();
                  if (!context.mounted) return;
                  await openCareFlow(
                    context,
                    profileId: profileId,
                    name: name,
                    profilePhotoUrl: profilePhotoUrl,
                    path: 'messages',
                  );
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Maybe later',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
