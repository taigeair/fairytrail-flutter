import 'package:fairytrail/analytics/appsflyer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitize keeps string, num, and bool values', () {
    expect(
      AppsFlyerService.sanitize({
        'name': 'gold',
        'price': 9.99,
        'count': 2,
        'trial': true,
      }),
      {'name': 'gold', 'price': 9.99, 'count': 2, 'trial': true},
    );
  });

  test('sanitize drops nulls and stringifies other values', () {
    expect(
      AppsFlyerService.sanitize({
        'empty': null,
        'tags': ['a', 'b'],
        'nested': {'tier': 'silver'},
      }),
      {'tags': '[a, b]', 'nested': '{tier: silver}'},
    );
  });

  test('uses the dashboard dev key and iOS App Store id', () {
    expect(AppsFlyerService.devKey, 'MrYwZS2MN2MsQ6w7je9Yh6');
    expect(AppsFlyerService.iosAppId, '1442011999');
  });
}
