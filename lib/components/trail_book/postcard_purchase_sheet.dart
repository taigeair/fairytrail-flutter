import 'package:fairytrail/config/billing_config.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Future<String?> showPostcardPurchaseSheet(
  BuildContext context, {
  required List<StoreProduct> products,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      StoreProduct? productFor(String id) {
        for (final p in products) {
          if (p.identifier == id) return p;
        }
        return null;
      }

      String priceLine(String id, int credits) {
        final p = productFor(id);
        if (p == null) return '$credits postcards';
        final each = credits > 0 ? p.price / credits : p.price;
        final symbol = p.priceString.replaceAll(RegExp(r'[\d.,\s]'), '');
        return '$credits postcards ${p.priceString}\n'
            '$symbol${each.toStringAsFixed(2)} each';
      }

      return AppSafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 48),
              padding: const EdgeInsets.fromLTRB(28, 64, 28, 24),
              decoration: BoxDecoration(
                color: AppColors.backgroundOf(ctx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppText(
                    'You are out of postcards',
                    variant: AppTextVariant.title,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AppText(
                    'Buy postcards to send words of encouragement.',
                    variant: AppTextVariant.body,
                    fontSize: 17,
                    textAlign: TextAlign.center,
                    color: AppColors.textPrimaryOf(ctx),
                  ),
                  const SizedBox(height: 20),
                  for (final id in BillingConfig.postcardProductIds) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B006E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          priceLine(
                            id,
                            BillingConfig.postcardCreditsByProduct[id] ?? 0,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.backgroundOf(ctx),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/trailBook/postcard.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
