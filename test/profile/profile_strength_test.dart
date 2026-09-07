import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/profile/profile_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns 100 when every edit-profile field and photo slot is filled', () {
    expect(calculateProfileStrength(_completeProfile()), 100);
  });

  test('stays below 100 when a field or photo slot is incomplete', () {
    final incomplete = _completeProfile().copyWith(
      photos: _completeProfile().photos.take(2).toList(),
      storyTime: '',
    );

    expect(calculateProfileStrength(incomplete), lessThan(100));
  });
}

FullProfileDto _completeProfile() => FullProfileDto(
  id: 1,
  name: 'Traveler',
  profileType: 'woman',
  photos: const [
    ProfilePhotoDto(attachmentId: '1', url: '1', thumbnailUrl: '1'),
    ProfilePhotoDto(attachmentId: '2', url: '2', thumbnailUrl: '2'),
    ProfilePhotoDto(attachmentId: '3', url: '3', thumbnailUrl: '3'),
  ],
  isVerified: true,
  status: 'approved',
  country: const CountryDto(id: 1, country: 'Poland'),
  age: 30,
  occupation: 'Designer',
  mobility: 'remote',
  storyTime: 'An adventure',
  upcomingDestinations: const [UpcomingDestinationDto(id: 2, name: 'Japan')],
  nationalities: const [NationalityDto(id: 1, name: 'Polish')],
  languages: const [LanguageDto(id: 1, language: 'Polish')],
  topWishes: 'See the world',
  myValues: 'Kindness',
  thingsILove: 'Travel',
  kindestThings: 'Helped someone',
  whatImDoingNow: 'Building an app',
  instagram: '@traveler',
  sexuality: 'straight',
);
