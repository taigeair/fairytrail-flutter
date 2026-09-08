import 'package:fairytrail/api/init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the React Native ad remote-config keys', () {
    final response = InitResponse.fromJson({
      'kv': {
        'ads_frequency': '7',
        'first_connect_ad_grace_actions': '12',
        'rewards_ads_frequency': '11',
        'native_ads_banner_image': 'https://example.com/ad.jpg',
        'native_ads_offer_url': 'https://example.com/offer',
        'verificationFeeGroup': ' verification_fee_499 ',
        'verificationButtonText': ' Verify - \$4.99 ',
      },
    });

    expect(response.adsFrequency, 7);
    expect(response.firstConnectAdGraceActions, 12);
    expect(response.rewardsAdsFrequency, 11);
    expect(response.nativeAdsBannerImage, 'https://example.com/ad.jpg');
    expect(response.nativeAdsOfferUrl, 'https://example.com/offer');
    expect(response.verificationFeeGroup, 'verification_fee_499');
    expect(response.verificationButtonText, 'Verify - \$4.99');
  });

  test('uses RN fallback and disables reward gate when keys are absent', () {
    final response = InitResponse.fromJson({'kv': <String, String>{}});

    expect(response.adsFrequency, 3);
    expect(response.firstConnectAdGraceActions, 60);
    expect(response.rewardsAdsFrequency, isNull);
    expect(response.nativeAdsBannerImage, isNull);
    expect(response.nativeAdsOfferUrl, isNull);
    expect(response.verificationFeeGroup, isNull);
    expect(response.verificationButtonText, isNull);
  });

  test('resolves silver weekly A/B package ids', () {
    expect(
      InitResponse.fromJson({
        'kv': {'silver_weekly_package_id': 'weekly_b'},
      }).silverWeeklyPackageId,
      'weekly_b',
    );
    expect(
      InitResponse.fromJson({
        'kv': {'silver_weekly_package_id': 'B'},
      }).silverWeeklyPackageId,
      'weekly_b',
    );
    expect(
      InitResponse.fromJson({
        'kv': {'silver_weekly_package_id_B': 'weekly_b'},
      }).silverWeeklyPackageId,
      'weekly_b',
    );
    expect(
      InitResponse.fromJson({
        'kv': {'silver_weekly_package_id_A': r'$rc_weekly'},
      }).silverWeeklyPackageId,
      r'$rc_weekly',
    );
    expect(
      InitResponse.fromJson({'kv': <String, String>{}}).silverWeeklyPackageId,
      r'$rc_weekly',
    );
  });

  test('allows first-connect ad grace to be disabled remotely', () {
    final response = InitResponse.fromJson({
      'kv': {'first_connect_ad_grace_actions': '0'},
    });

    expect(response.firstConnectAdGraceActions, 0);
  });
}
