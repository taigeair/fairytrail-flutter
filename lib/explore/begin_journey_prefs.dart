import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/prefs.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';

/// Same prefs seed as Begin Journey "Get Started" — shared so warm prefetch
/// can run it before the button is tapped.
///
/// Does **not** call refreshMe — keeps local matchWithCount low so Begin Journey
/// UI still shows until the user taps.
Future<bool> seedBeginJourneyPrefsIfNeeded(ProfileMetaDto? meta) async {
  if (meta != null && meta.matchWithCount >= 1) return false;

  int? ageFrom;
  int? ageTo;
  final profileType = meta?.profileType;
  final age = meta?.age;
  if (age != null &&
      profileType != null &&
      profileType != 'couple' &&
      profileType != 'family') {
    ageFrom = (age - 10).clamp(18, 99);
    ageTo = (age + 10).clamp(18, 99);
  }

  List<int> upcoming = const [];
  try {
    final props = await getEditProfileProps();
    final destinations = props.profile?.upcomingDestinations ?? const [];
    upcoming = UpcomingDestinations.filterableIds(destinations);
  } catch (_) {}

  await putPrefs(
    UserPrefsDto(
      matchWith: [for (final o in matchWithOptions) o.$2],
      ageFrom: ageFrom ?? 18,
      ageTo: ageTo ?? 99,
      upcomingCountries: upcoming,
      openTo: const [],
    ),
  );
  return true;
}
