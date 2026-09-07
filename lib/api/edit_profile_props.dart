import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/utils/api/end_points.dart';
import 'package:fairytrail/utils/api/https.dart';

class EditProfilePropsResponse {
  const EditProfilePropsResponse({
    this.profile,
    required this.countries,
    this.languages = const [],
    this.nationalities = const [],
  });

  final FullProfileDto? profile;
  final List<CountryDto> countries;
  final List<LanguageDto> languages;
  final List<NationalityDto> nationalities;

  factory EditProfilePropsResponse.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['profile'];
    return EditProfilePropsResponse(
      profile: profileRaw is Map
          ? FullProfileDto.fromJson(Map<String, dynamic>.from(profileRaw))
          : null,
      countries: CountryDto.listFromJson(json['countries']),
      languages: (json['languages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => LanguageDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      nationalities: (json['nationalities'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NationalityDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// GET /api/v1/edit-profile-props
Future<EditProfilePropsResponse> getEditProfileProps() async {
  final response = await HttpClient.instance.request(
    path: EndPoints.editProfileProps,
    method: HttpMethod.get,
    requiresAuth: true,
  );

  final data = response.data;
  if (data is! Map) {
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Unexpected edit-profile-props response',
      payload: data,
    );
  }

  return EditProfilePropsResponse.fromJson(Map<String, dynamic>.from(data));
}
