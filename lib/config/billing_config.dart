/// Public RevenueCat SDK keys (same as React Native app).
abstract final class BillingConfig {
  static const appleApiKey = 'appl_GSjUGZrqonxSyPciprhIusvcCyf';
  static const googleApiKey = 'goog_GfpiKexNWQzDKwCFonwwazAzBXS';

  /// Fallback when remote-config `verificationFeeGroup` is unavailable.
  /// Staging/prod currently serve `free_plan_offering_499` ($4.99).
  static const verificationOfferingId = 'free_plan_offering_499';

  static const verificationScreenTitle = 'Build trust with verified badge';

  /// RevenueCat offering for Truth Serum (Photo Epicness) lifetime IAP.
  static const truthSerumOfferingId = 'truth_serum';

  /// RevenueCat offering for postcard IAP packs.
  static const postcardsOfferingId = 'postcards_fee';

  static const postcardProductIds = [
    'postcards_payment_1',
    'postcards_payment_2',
    'postcards_payment_3',
  ];

  /// Credits granted per product (matches API UpdatePostcardsController).
  static const postcardCreditsByProduct = {
    'postcards_payment_1': 3,
    'postcards_payment_2': 10,
    'postcards_payment_3': 30,
  };
}
