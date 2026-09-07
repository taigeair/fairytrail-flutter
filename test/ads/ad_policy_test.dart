import 'package:fairytrail/ads/ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('first-connect ad grace', () {
    test('suppresses ads until grace state has loaded', () {
      expect(
        AdPolicy.isInFirstConnectGrace(
          graceLoaded: false,
          graceThroughAction: null,
          totalActions: 50,
        ),
        isTrue,
      );
    });

    test('includes every action through the persisted boundary', () {
      expect(
        AdPolicy.isInFirstConnectGrace(
          graceLoaded: true,
          graceThroughAction: 14,
          totalActions: 14,
        ),
        isTrue,
      );
      expect(
        AdPolicy.isInFirstConnectGrace(
          graceLoaded: true,
          graceThroughAction: 14,
          totalActions: 15,
        ),
        isFalse,
      );
    });

    test('has no grace when no boundary was persisted', () {
      expect(
        AdPolicy.isInFirstConnectGrace(
          graceLoaded: true,
          graceThroughAction: null,
          totalActions: 1,
        ),
        isFalse,
      );
    });
  });

  group('action ad checkpoints', () {
    test('first action check seeds checkpoint without showing an ad', () {
      final result = AdPolicy.actionDecision(
        totalActions: 10,
        frequency: 3,
        checkpoint: null,
      );

      expect(result.nextCheckpoint, 13);
      expect(result.showAd, isFalse);
    });

    test('reached checkpoint shows and advances from current total', () {
      final result = AdPolicy.actionDecision(
        totalActions: 13,
        frequency: 3,
        checkpoint: 13,
      );

      expect(result.nextCheckpoint, 16);
      expect(result.showAd, isTrue);
    });

    test('seeds from before the current action', () {
      final result = AdPolicy.actionDecision(
        totalActions: 1,
        previousTotalActions: 0,
        frequency: 5,
        checkpoint: null,
      );

      expect(result.nextCheckpoint, 5);
      expect(result.showAd, isFalse);
    });

    test('shows on the fifth action rather than the sixth', () {
      final result = AdPolicy.actionDecision(
        totalActions: 5,
        previousTotalActions: 4,
        frequency: 5,
        checkpoint: 5,
      );

      expect(result.nextCheckpoint, 10);
      expect(result.showAd, isTrue);
    });

    test('recovers a checkpoint left ahead by another user', () {
      final result = AdPolicy.actionDecision(
        totalActions: 5,
        previousTotalActions: 4,
        frequency: 5,
        checkpoint: 100,
      );

      expect(result.nextCheckpoint, 9);
      expect(result.showAd, isFalse);
    });

    test('past checkpoint also shows and catches checkpoint up', () {
      final result = AdPolicy.actionDecision(
        totalActions: 18,
        frequency: 3,
        checkpoint: 16,
      );

      expect(result.nextCheckpoint, 21);
      expect(result.showAd, isTrue);
    });

    test('frequency five shows exactly on actions five and ten', () {
      int? checkpoint;
      final shownAt = <int>[];

      for (var action = 1; action <= 10; action++) {
        final result = AdPolicy.actionDecision(
          totalActions: action,
          previousTotalActions: action - 1,
          frequency: 5,
          checkpoint: checkpoint,
        );
        checkpoint = result.nextCheckpoint;
        if (result.showAd) shownAt.add(action);
      }

      expect(shownAt, [5, 10]);
    });
  });

  test('reward gate is free-tier, frequency, and daily-reward controlled', () {
    expect(
      AdPolicy.shouldShowRewardGate(
        tier: 'free',
        dailyActions: 5,
        frequency: 5,
        rewardTakenToday: false,
      ),
      isTrue,
    );
    expect(
      AdPolicy.shouldShowRewardGate(
        tier: 'gold',
        dailyActions: 10,
        frequency: 5,
        rewardTakenToday: false,
      ),
      isFalse,
    );
    expect(
      AdPolicy.shouldShowRewardGate(
        tier: 'gated',
        dailyActions: 10,
        frequency: 5,
        rewardTakenToday: true,
      ),
      isFalse,
    );
  });

  test('first-time users are excluded from all ad-supported tiers', () {
    expect(AdPolicy.isAdSupportedTier('gated', isFirstTimeUser: true), isFalse);
    expect(
      AdPolicy.shouldShowRewardGate(
        tier: 'gated',
        dailyActions: 50,
        frequency: 5,
        rewardTakenToday: false,
        isFirstTimeUser: true,
      ),
      isFalse,
    );
  });
}
