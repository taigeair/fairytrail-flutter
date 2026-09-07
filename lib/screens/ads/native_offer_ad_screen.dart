import 'package:cached_network_image/cached_network_image.dart';
import 'package:fairytrail/ads/open_ad_url.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class NativeOfferAdScreen extends StatelessWidget {
  const NativeOfferAdScreen({
    super.key,
    required this.imageUrl,
    required this.offerUrl,
  });

  final String? imageUrl;
  final String? offerUrl;

  static Future<void> open(
    BuildContext context, {
    required String? imageUrl,
    required String? offerUrl,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          NativeOfferAdScreen(imageUrl: imageUrl, offerUrl: offerUrl),
    ),
  );

  Future<void> _close(BuildContext context) async {
    await LocalStorage.instance.deleteBannerAdsScreenViewed();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _learnMore(BuildContext context) async {
    await openAdUrlInBrowser(offerUrl);
    if (context.mounted) await _close(context);
  }

  @override
  Widget build(BuildContext context) {
    final validImage = Uri.tryParse(imageUrl ?? '')?.hasScheme == true;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 320,
                  child: ColoredBox(
                    color: AppColors.surfaceOf(context),
                    child: validImage
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallbackImage(),
                          )
                        : _fallbackImage(),
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Learn more',
                onPressed: () => _learnMore(context),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Skip',
                variant: AppButtonVariant.secondary,
                onPressed: () => _close(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() =>
      Image.asset('assets/trailBook/postcard.png', fit: BoxFit.contain);
}
