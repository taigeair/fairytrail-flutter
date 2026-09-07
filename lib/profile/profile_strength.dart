import 'package:fairytrail/api/models/explore_models.dart';

/// Calculates local profile completion from the fields shown on Edit Profile.
/// Each visible field and each of the three photo slots has equal weight.
int calculateProfileStrength(FullProfileDto profile) {
  final completed = <bool>[
    profile.photos.isNotEmpty,
    profile.photos.length >= 2,
    profile.photos.length >= 3,
    profile.country != null,
    profile.upcomingDestinations.isNotEmpty,
    profile.name.trim().isNotEmpty,
    if (_showsAge(profile.profileType)) profile.age != null,
    _hasText(profile.occupation),
    // A null travel style represents the valid default "Solo Traveler".
    true,
    _hasText(profile.mobility),
    profile.nationalities.isNotEmpty,
    profile.languages.isNotEmpty,
    _hasText(profile.sexuality),
    _hasText(profile.instagram),
    _hasText(profile.storyTime),
    _hasText(profile.topWishes),
    _hasText(profile.whatImDoingNow),
    _hasText(profile.myValues),
    _hasText(profile.thingsILove),
    _hasText(profile.kindestThings),
  ];

  final filled = completed.where((value) => value).length;
  return ((filled / completed.length) * 100).round().clamp(0, 100);
}

bool _hasText(String? value) => value?.trim().isNotEmpty ?? false;

bool _showsAge(String profileType) =>
    profileType == 'man' ||
    profileType == 'woman' ||
    profileType == 'non-binary' ||
    profileType.isEmpty;
