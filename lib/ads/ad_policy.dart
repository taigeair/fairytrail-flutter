enum ExploreAdPlacement { interstitial }

class ActionAdDecision {
  const ActionAdDecision({required this.nextCheckpoint, required this.showAd});

  final int nextCheckpoint;
  final bool showAd;
}

/// Pure decision rules matching the React Native Explore ad checkpoints.
abstract final class AdPolicy {
  static bool isAdSupportedTier(String tier, {bool isFirstTimeUser = false}) =>
      !isFirstTimeUser && (tier == 'gated' || tier == 'free');

  static bool isInFirstConnectGrace({
    required bool graceLoaded,
    required int? graceThroughAction,
    required int? totalActions,
  }) {
    if (!graceLoaded) return true;
    if (graceThroughAction == null) return false;
    return totalActions == null || totalActions <= graceThroughAction;
  }

  static ActionAdDecision actionDecision({
    required int totalActions,
    required int frequency,
    required int? checkpoint,
    int? previousTotalActions,
  }) {
    final safeFrequency = frequency > 0 ? frequency : 3;
    var effectiveCheckpoint = checkpoint;

    // Seed from the count before the current action, so action 5 reaches a
    // frequency-5 checkpoint instead of scheduling the first ad for action 6.
    // Also recover from a checkpoint left by another signed-in user.
    if (effectiveCheckpoint == null) {
      effectiveCheckpoint =
          (previousTotalActions ?? totalActions) + safeFrequency;
    } else if (effectiveCheckpoint > totalActions + safeFrequency) {
      effectiveCheckpoint =
          (previousTotalActions ?? totalActions) + safeFrequency;
    }
    if (effectiveCheckpoint <= totalActions) {
      return ActionAdDecision(
        nextCheckpoint: totalActions + safeFrequency,
        showAd: true,
      );
    }
    return ActionAdDecision(nextCheckpoint: effectiveCheckpoint, showAd: false);
  }

  static bool shouldShowRewardGate({
    required String tier,
    required int dailyActions,
    required int? frequency,
    required bool rewardTakenToday,
    bool isFirstTimeUser = false,
  }) {
    return isAdSupportedTier(tier, isFirstTimeUser: isFirstTimeUser) &&
        frequency != null &&
        frequency > 0 &&
        dailyActions >= frequency &&
        !rewardTakenToday;
  }
}
