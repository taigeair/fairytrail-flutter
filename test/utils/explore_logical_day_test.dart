import 'package:fairytrail/utils/explore_logical_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('exploreLogicalDayKey', () {
    test('uses the previous day before 4 AM', () {
      expect(
        exploreLogicalDayKey(DateTime(2026, 8, 9, 3, 59, 59)),
        '2026-08-08',
      );
    });

    test('starts a new day at 4 AM', () {
      expect(exploreLogicalDayKey(DateTime(2026, 8, 9, 4)), '2026-08-09');
    });

    test('handles month and year boundaries', () {
      expect(exploreLogicalDayKey(DateTime(2026, 1, 1)), '2025-12-31');
    });
  });

  group('nextExploreLogicalDayStart', () {
    test('points at today 4 AM when still before it', () {
      expect(
        nextExploreLogicalDayStart(DateTime(2026, 8, 9, 3, 59, 59)),
        DateTime(2026, 8, 9, 4),
      );
    });

    test('points at tomorrow 4 AM once the day has started', () {
      expect(
        nextExploreLogicalDayStart(DateTime(2026, 8, 9, 4)),
        DateTime(2026, 8, 10, 4),
      );
      expect(
        nextExploreLogicalDayStart(DateTime(2026, 8, 9, 15)),
        DateTime(2026, 8, 10, 4),
      );
    });
  });

  group('durationUntilNextExploreLogicalDay', () {
    test('is the remaining time before 4 AM', () {
      expect(
        durationUntilNextExploreLogicalDay(DateTime(2026, 8, 9, 3, 30)),
        const Duration(minutes: 30),
      );
    });

    test('spans overnight after 4 AM', () {
      expect(
        durationUntilNextExploreLogicalDay(DateTime(2026, 8, 9, 4)),
        const Duration(hours: 24),
      );
    });
  });
}
