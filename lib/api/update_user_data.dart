import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

/// PUT /api/v1/user-data — update profile fields during/after signup.
///
/// When [fullUpdate] is true, nullable fields are always sent (including JSON
/// null) so the server can clear values — used by edit profile.
Future<void> updateUserData({
  required String name,
  required String mobility,
  String? storyTime,
  int? age,
  int? countryId,
  List<int>? upcomingCountries,
  List<int>? upcomingCities,
  List<int>? visitedCountries,
  String? occupation,
  List<int>? nationalities,
  List<int>? languages,
  String? sexuality,
  String? topWishes,
  String? myValues,
  String? thingsILove,
  String? kindestThings,
  String? whatImDoingNow,
  List<String>? openTo,
  String? instagram,
  String? travelStyle,
  List<String>? motives,
  bool fullUpdate = false,

  /// Skip Mixpanel `updated_profile` on the backend (signup funnel).
  bool skip = false,
}) async {
  final body = <String, dynamic>{
    'name': name,
    'mobility': mobility,
  };

  if (skip) body['skip'] = true;

  if (fullUpdate) {
    body.addAll({
      'age': age,
      'countryId': countryId,
      'upcomingCountries': upcomingCountries ?? const <int>[],
      'upcomingCities': upcomingCities ?? const <int>[],
      'occupation': occupation,
      'nationalities': nationalities ?? const <int>[],
      'languages': languages ?? const <int>[],
      'sexuality': sexuality,
      'storyTime': storyTime,
      'topWishes': topWishes,
      'myValues': myValues,
      'thingsILove': thingsILove,
      'kindestThings': kindestThings,
      'whatImDoingNow': whatImDoingNow,
      'openTo': openTo ?? const <String>[],
      'instagram': instagram,
      'travelStyle': travelStyle,
      'motives': motives ?? const <String>[],
    });
  } else {
    if (storyTime != null) body['storyTime'] = storyTime;
    if (age != null) body['age'] = age;
    if (upcomingCountries != null) {
      body['upcomingCountries'] = upcomingCountries;
    }
    if (upcomingCities != null) {
      body['upcomingCities'] = upcomingCities;
    }
    if (visitedCountries != null) {
      body['visitedCountries'] = visitedCountries;
    }
    if (travelStyle != null) body['travelStyle'] = travelStyle;
    if (motives != null) body['motives'] = motives;
  }

  await HttpClient.instance.request(
    path: EndPoints.userData,
    method: HttpMethod.put,
    requiresAuth: true,
    body: body,
  );
}

/// Backward-compatible alias used by older signup photo step.
Future<void> updateUserStory({
  required String name,
  required String mobility,
  required String storyTime,
  int? age,
}) =>
    updateUserData(
      name: name,
      mobility: mobility,
      storyTime: storyTime,
      age: age,
    );
