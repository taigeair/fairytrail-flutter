import 'package:fairytrail/tracking/tracking_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'requests once when status is not determined and allows tracking',
    () async {
      final client = _FakeClient(
        statusResult: AppTrackingConsentStatus.notDetermined,
        requestResult: AppTrackingConsentStatus.authorized,
      );
      final decisions = <bool>[];
      final service = TrackingConsentService(
        client: client,
        initializeTracking: (allowed) async => decisions.add(allowed),
        delay: (_) async {},
      );

      await service.requestAfterInterfaceIsVisible(isAppActive: () => true);
      await service.requestAfterInterfaceIsVisible(isAppActive: () => true);

      expect(client.statusCalls, 1);
      expect(client.requestCalls, 1);
      expect(decisions, [true]);
    },
  );

  for (final status in [
    AppTrackingConsentStatus.denied,
    AppTrackingConsentStatus.restricted,
    AppTrackingConsentStatus.notSupported,
  ]) {
    test('$status disables tracking without requesting again', () async {
      final client = _FakeClient(statusResult: status);
      final decisions = <bool>[];
      final service = TrackingConsentService(
        client: client,
        initializeTracking: (allowed) async => decisions.add(allowed),
        delay: (_) async {},
      );

      await service.requestAfterInterfaceIsVisible(isAppActive: () => true);

      expect(client.requestCalls, 0);
      expect(decisions, [false]);
    });
  }

  test('not determined result after request disables tracking', () async {
    final client = _FakeClient(
      statusResult: AppTrackingConsentStatus.notDetermined,
      requestResult: AppTrackingConsentStatus.notDetermined,
    );
    final decisions = <bool>[];
    final service = TrackingConsentService(
      client: client,
      initializeTracking: (allowed) async => decisions.add(allowed),
      delay: (_) async {},
    );

    await service.requestAfterInterfaceIsVisible(isAppActive: () => true);

    expect(decisions, [false]);
  });

  test('does not check or request while app is inactive', () async {
    final client = _FakeClient(
      statusResult: AppTrackingConsentStatus.notDetermined,
    );
    final decisions = <bool>[];
    final service = TrackingConsentService(
      client: client,
      initializeTracking: (allowed) async => decisions.add(allowed),
      delay: (_) async {},
    );

    await service.requestAfterInterfaceIsVisible(isAppActive: () => false);

    expect(client.statusCalls, 0);
    expect(client.requestCalls, 0);
    expect(decisions, isEmpty);
  });

  test('non-iOS initializes normally without platform API calls', () async {
    final client = _FakeClient(
      usesAppTrackingTransparency: false,
      statusResult: AppTrackingConsentStatus.notSupported,
    );
    final decisions = <bool>[];
    final service = TrackingConsentService(
      client: client,
      initializeTracking: (allowed) async => decisions.add(allowed),
      delay: (_) async {},
    );

    await service.requestAfterInterfaceIsVisible(isAppActive: () => true);

    expect(client.statusCalls, 0);
    expect(client.requestCalls, 0);
    expect(decisions, [true]);
  });
}

class _FakeClient implements TrackingAuthorizationClient {
  _FakeClient({
    required this.statusResult,
    this.requestResult = AppTrackingConsentStatus.denied,
    this.usesAppTrackingTransparency = true,
  });

  final AppTrackingConsentStatus statusResult;
  final AppTrackingConsentStatus requestResult;

  @override
  final bool usesAppTrackingTransparency;

  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<AppTrackingConsentStatus> status() async {
    statusCalls++;
    return statusResult;
  }

  @override
  Future<AppTrackingConsentStatus> request() async {
    requestCalls++;
    return requestResult;
  }
}
