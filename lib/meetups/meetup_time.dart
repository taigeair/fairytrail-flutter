/// Relative meetup start label for chat headers.
///
/// Before start: `in 1 day` / `in 3 hours`
/// After start: `1 day ago` / `3 hours ago`
/// Under 1 hour: `in less than an hour` / `less than an hour ago`
String meetupStartsRelativeLabel(DateTime startsAt) {
  final now = DateTime.now();
  final start = startsAt.toLocal();
  final diff = start.difference(now);
  final future = !diff.isNegative;
  final abs = diff.abs();

  if (abs.inHours < 24) {
    final hours = abs.inHours;
    if (hours < 1) {
      return future ? 'in less than an hour' : 'less than an hour ago';
    }
    final unit = hours == 1 ? 'hour' : 'hours';
    return future ? 'in $hours $unit' : '$hours $unit ago';
  }

  final days = abs.inDays < 1 ? 1 : abs.inDays;
  final unit = days == 1 ? 'day' : 'days';
  return future ? 'in $days $unit' : '$days $unit ago';
}
