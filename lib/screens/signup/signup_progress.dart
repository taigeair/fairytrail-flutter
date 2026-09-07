/// Weighted signup progress bar.
abstract final class SignupProgress {
  // Front-loaded to create early momentum, then advances on every actionable
  // screen so the final stretch never feels stalled.
  static const weightsByStep = <int, double>{
    1: 6.0, // Basics
    2: 6.0, // Motives
    3: 6.0, // Travel
    5: 5.0, // Social proof
    6: 5.0, // Photos
    7: 1.0, // Preview
    8: 1.0, // Destination
    9: 1.0, // Location
    10: 1.0, // Rate
    12: 1.0, // Story Time
    11: 0.0, // Upgrade or free trial
  };

  static double valueForStep(int step) {
    // Insertion order is the display order; persisted IDs are not sequential.
    final current = step == 4 ? 5 : step;
    final total = weightsByStep.values.fold(0.0, (sum, weight) => sum + weight);
    var completed = 0.0;
    for (final entry in weightsByStep.entries) {
      completed += entry.value;
      if (entry.key == current) break;
    }
    return (completed / total).clamp(0.0, 1.0);
  }
}
