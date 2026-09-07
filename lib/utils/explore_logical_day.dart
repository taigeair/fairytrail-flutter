/// Explore's daily counters reset at 4:00 AM in the user's local timezone,
/// matching the backend action-count query.
const Duration exploreLogicalDayOffset = Duration(hours: 4);

/// Returns the calendar key for the Explore logical day containing [value].
///
/// Times before 4:00 AM belong to the preceding logical day.
String exploreLogicalDayKey([DateTime? value]) {
  final shifted = (value ?? DateTime.now()).subtract(exploreLogicalDayOffset);
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}-'
      '${shifted.day.toString().padLeft(2, '0')}';
}

/// Next 4:00 AM local boundary at or after which a new Explore day starts.
///
/// If [value] is already exactly 4:00 AM, returns that instant (day already
/// started). Otherwise returns the upcoming 4:00 AM.
DateTime nextExploreLogicalDayStart([DateTime? value]) {
  final now = value ?? DateTime.now();
  final todayReset = DateTime(now.year, now.month, now.day).add(
    exploreLogicalDayOffset,
  );
  if (now.isBefore(todayReset)) return todayReset;
  return todayReset.add(const Duration(days: 1));
}

/// Delay until [nextExploreLogicalDayStart]. Never negative.
Duration durationUntilNextExploreLogicalDay([DateTime? value]) {
  final now = value ?? DateTime.now();
  final next = nextExploreLogicalDayStart(now);
  final delay = next.difference(now);
  return delay.isNegative ? Duration.zero : delay;
}
