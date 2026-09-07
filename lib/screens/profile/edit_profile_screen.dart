import 'dart:async';
import 'dart:io';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/edit_profile_props.dart';
import 'package:fairytrail/api/location.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/prefs.dart';
import 'package:fairytrail/api/profile_photos.dart';
import 'package:fairytrail/api/update_user_data.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/explore/explore_profile_card.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/registration_options.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/config/upcoming_destinations.dart';
import 'package:fairytrail/location/location_service.dart';
import 'package:fairytrail/profile/profile_strength.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/api/https.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/image_pick_crop.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _maxPhotos = 3;

enum _EditTab { edit, preview }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.startInPreview = false});

  final bool startInPreview;

  static Future<void> open(
    BuildContext context, {
    bool startInPreview = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditProfileScreen(startInPreview: startInPreview),
      ),
    );
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _saving = false;
  bool _detectingCountry = false;
  bool _dirty = false;
  String? _error;
  late _EditTab _tab;
  late final TabController _tabController;

  FullProfileDto? _profile;
  List<CountryDto> _countries = [];
  List<LanguageDto> _languages = [];
  List<NationalityDto> _nationalities = [];

  late final TextEditingController _nameController;
  late final TextEditingController _occupationController;
  late final TextEditingController _instagramController;
  late final TextEditingController _storyController;
  late final TextEditingController _wishesController;
  late final TextEditingController _doingNowController;
  late final TextEditingController _valuesController;
  late final TextEditingController _lovesController;
  late final TextEditingController _kindestController;

  final Set<int> _uploadingSlots = {};

  @override
  void initState() {
    super.initState();
    _tab = widget.startInPreview ? _EditTab.preview : _EditTab.edit;
    _tabController =
        TabController(
          length: 2,
          initialIndex: _tab == _EditTab.edit ? 0 : 1,
          vsync: this,
        )..addListener(() {
          final tab = _tabController.index == 0
              ? _EditTab.edit
              : _EditTab.preview;
          if (mounted && tab != _tab) setState(() => _tab = tab);
        });
    _nameController = TextEditingController();
    _occupationController = TextEditingController();
    _instagramController = TextEditingController();
    _storyController = TextEditingController();
    _wishesController = TextEditingController();
    _doingNowController = TextEditingController();
    _valuesController = TextEditingController();
    _lovesController = TextEditingController();
    _kindestController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _occupationController.dispose();
    _instagramController.dispose();
    _storyController.dispose();
    _wishesController.dispose();
    _doingNowController.dispose();
    _valuesController.dispose();
    _lovesController.dispose();
    _kindestController.dispose();
    super.dispose();
  }

  bool get _showAge {
    final type = _profile?.profileType ?? '';
    return type == 'man' ||
        type == 'woman' ||
        type == 'non-binary' ||
        type.isEmpty;
  }

  bool get _canUploadPhotos {
    final status = AuthScope.of(context).user?.accountStatus;
    return status == null || status == 'active';
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _syncControllers(FullProfileDto p) {
    _nameController.text = p.name;
    _occupationController.text = p.occupation ?? '';
    _instagramController.text = p.instagram ?? '';
    _storyController.text = p.storyTime ?? '';
    _wishesController.text = p.topWishes ?? '';
    _doingNowController.text = p.whatImDoingNow ?? '';
    _valuesController.text = p.myValues ?? '';
    _lovesController.text = p.thingsILove ?? '';
    _kindestController.text = p.kindestThings ?? '';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await getEditProfileProps();
      final profile = res.profile;
      if (profile == null) {
        throw ApiException(statusCode: 200, message: 'Profile not found');
      }
      if (!mounted) return;
      _syncControllers(profile);
      await LocalStorage.instance.setProfileStrength(
        calculateProfileStrength(profile),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _countries = res.countries;
        _languages = res.languages;
        _nationalities = res.nationalities;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _loading = false;
      });
    }
  }

  Future<bool> _saveIfNeeded() async {
    final profile = _profile;
    if (profile == null || !_dirty) return true;

    setState(() => _saving = true);
    try {
      final bg = BackgroundPhotoUpload.instance.status;
      final bgBusy =
          bg != BackgroundPhotoUploadStatus.idle &&
          bg != BackgroundPhotoUploadStatus.done;

      final photosFuture = bgBusy
          ? Future<void>.value()
          : attachProfilePhotos(
              attachmentIds: profile.photos.map((p) => p.attachmentId).toList(),
            );

      await Future.wait([
        updateUserData(
          name: _nameController.text.trim().isEmpty
              ? profile.name
              : _nameController.text.trim(),
          mobility: profile.mobility ?? 'non-remote',
          age: _showAge ? profile.age : null,
          countryId: profile.country?.id,
          upcomingCountries: profile.upcomingDestinations
              .map((d) => d.id)
              .toList(),
          upcomingCities: const [],
          occupation: _occupationController.text.trim(),
          nationalities: profile.nationalities.map((n) => n.id).toList(),
          languages: profile.languages.map((l) => l.id).toList(),
          sexuality: profile.sexuality,
          storyTime: _storyController.text.trim(),
          topWishes: _wishesController.text.trim(),
          myValues: _valuesController.text.trim(),
          thingsILove: _lovesController.text.trim(),
          kindestThings: _kindestController.text.trim(),
          whatImDoingNow: _doingNowController.text.trim(),
          openTo: profile.openTo,
          instagram: _instagramController.text.trim().isEmpty
              ? null
              : _instagramController.text.trim(),
          travelStyle: profile.travelStyle,
          motives: profile.motives,
          fullUpdate: true,
        ),
        photosFuture,
      ]);

      // Apply upcoming destinations to Explore "Traveling to" filter
      // (excludes synthetic "None" — that opts out of destination matching).
      final upcomingIds =
          UpcomingDestinations.filterableIds(profile.upcomingDestinations);
      try {
        final prefsRes = await getPrefs();
        await putPrefs(
          prefsRes.userPrefs.copyWith(
            upcomingCountries: upcomingIds,
            openTo: const [],
          ),
        );
      } catch (_) {}

      if (!mounted) return true;
      await LocalStorage.instance.setProfileStrength(
        calculateProfileStrength(_previewProfile()),
      );
      if (!mounted) return true;
      await AuthScope.of(context).refreshMe();
      if (!mounted) return true;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      unawaited(AnalyticsService.instance.logEvent('updated_profile'));
      AppToast.show(context, message: 'Saved');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _saving = false);
      AppToast.show(context, message: serverErrorText(e));
      return false;
    }
  }

  Future<void> _onBack() async {
    final ok = await _saveIfNeeded();
    if (!mounted || !ok) return;
    Navigator.of(context).pop();
  }

  Future<void> _detectCountry() async {
    if (_detectingCountry || _countries.isEmpty) return;
    setState(() => _detectingCountry = true);
    try {
      // Await fresh GPS; 0.5mi buffer for server/country only (local always updates).
      final outcome = await LocationService.shareCurrentLocation(
        updateCountry: true,
        minDistanceMeters: LocationService.profileCountryUpdateBufferMeters,
        logTag: 'ProfileCountry',
        awaitFresh: true,
      );
      if (!outcome.isSuccess) {
        if (!mounted) return;
        if (outcome.result == LocationShareResult.permissionPermanentlyDenied) {
          final open = await AppDialog.confirm(
            context,
            title: 'Location access',
            message:
                'To detect your country, enable location permission in Settings.',
            confirmLabel: 'Open Settings',
            cancelLabel: 'OK',
          );
          if (open) await LocationService.openAppSettings();
        } else {
          AppToast.show(
            context,
            message: outcome.errorMessage ?? 'Could not detect country',
          );
        }
        return;
      }

      debugPrint(
        '[ProfileCountry] tap refresh '
        'previousCountry=${_profile?.country?.country} '
        'previousId=${_profile?.country?.id} '
        'gps=(${outcome.latitude}, ${outcome.longitude}) '
        'buffer=${LocationService.profileCountryUpdateBufferMiles}mi '
        'skippedDueToBuffer=${outcome.skippedDueToBuffer}',
      );

      if (outcome.skippedDueToBuffer) {
        debugPrint(
          '[ProfileCountry] skip country UI update — within '
          '${LocationService.profileCountryUpdateBufferMiles}mi buffer',
        );
        if (!mounted) return;
        AppToast.show(context, message: 'Country updated');
        return;
      }

      final lat = outcome.latitude;
      final lng = outcome.longitude;
      if (lat == null || lng == null) {
        debugPrint('[ProfileCountry] missing GPS coords after share');
        return;
      }

      final countryId = await postCountryIdFromCoordinates(
        latitude: lat,
        longitude: lng,
      );
      debugPrint(
        '[ProfileCountry] country-id API → $countryId for ($lat, $lng)',
      );
      if (countryId == null || !mounted) return;
      CountryDto? matched;
      for (final c in _countries) {
        if (c.id == countryId) {
          matched = c;
          break;
        }
      }
      if (matched == null || _profile == null) {
        debugPrint(
          '[ProfileCountry] no matching CountryDto for id=$countryId '
          '(countries=${_countries.length})',
        );
        return;
      }
      debugPrint(
        '[ProfileCountry] updating UI country '
        '${_profile!.country?.country} → ${matched.country} (id=${matched.id})',
      );
      setState(() {
        _profile = _profile!.copyWith(country: matched);
        _dirty = true;
      });
    } catch (e) {
      debugPrint('[ProfileCountry] detect failed: $e');
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _detectingCountry = false);
    }
  }

  Future<void> _pickPhoto(int index) async {
    if (!_canUploadPhotos) {
      AppToast.show(context, message: 'Photo edits are disabled while paused.');
      return;
    }
    if (_uploadingSlots.contains(index)) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => AppSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await pickAndCropSquareImage(source: source);
      if (file == null || !mounted) return;

      setState(() => _uploadingSlots.add(index));

      final bytes = await File(file.path).readAsBytes();
      final signed = await createAttachment(
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await uploadBytesToSignedUrl(uploadUrl: signed.uploadUrl, bytes: bytes);

      if (!mounted) return;
      final photo = ProfilePhotoDto(
        attachmentId: signed.attachmentId,
        url: file.path,
        thumbnailUrl: file.path,
      );
      final photos = List<ProfilePhotoDto>.from(_profile!.photos);
      // Keep a dense list of up to 3 photos (RN-style fixed slots).
      final slot = index.clamp(0, _maxPhotos - 1);
      if (slot < photos.length) {
        photos[slot] = photo;
      } else if (photos.length < _maxPhotos) {
        photos.add(photo);
      }

      setState(() {
        _profile = _profile!.copyWith(photos: photos);
        _uploadingSlots.remove(index);
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingSlots.remove(index));
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _pickSingle({
    required String title,
    required List<(String, String)> options,
    required String? selected,
    required ValueChanged<String?> onChanged,
    bool allowNone = false,
  }) async {
    var current = selected;
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AppSafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppText(
                              title,
                              variant: AppTextVariant.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (allowNone)
                            AppButton(
                              label: 'None',
                              variant: AppButtonVariant.text,
                              isExpanded: false,
                              onPressed: () => Navigator.pop(ctx, ''),
                            ),
                          AppButton(
                            label: 'Done',
                            variant: AppButtonVariant.text,
                            isExpanded: false,
                            onPressed: () => Navigator.pop(ctx, current ?? ''),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final opt = options[i];
                          final checked = current == opt.$2;
                          return ListTile(
                            title: AppText(opt.$1),
                            trailing: checked
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () => setLocal(() => current = opt.$2),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    final next = result.isEmpty ? null : result;
    if (next == selected) return;
    onChanged(next);
    _markDirty();
  }

  Future<void> _pickMultiInt({
    required String title,
    required List<(int, String)> items,
    required List<int> selected,
    required int limit,
    required ValueChanged<List<int>> onChanged,
  }) async {
    final result = await AppMultiSelectSheet.show<int>(
      context,
      title: title,
      items: [
        for (final e in items) AppMultiSelectItem(value: e.$1, label: e.$2),
      ],
      selected: selected,
      searchable: true,
      limit: limit,
    );
    if (result == null) return;
    onChanged(result);
    _markDirty();
  }

  /// Anywhere (empty), None (exclusive), or up to 5 real countries.
  Future<void> _pickUpcomingDestinations({
    required List<int> selected,
    required ValueChanged<List<UpcomingDestinationDto>> onChanged,
  }) async {
    const anywhereId = -1;
    final none = UpcomingDestinations.noneOf(_countries);
    final real = UpcomingDestinations.realCountries(_countries);

    final openToAll = selected.isEmpty;
    final noneOnly =
        none != null && selected.length == 1 && selected.first == none.id;

    var mode = openToAll
        ? 'anywhere'
        : noneOnly
        ? 'none'
        : 'countries';
    var current = noneOnly
        ? <int>[]
        : List<int>.from(selected.where((id) => id != none?.id));

    // Checked countries first on open only — toggles do not reorder.
    final orderedCountries = selectedFirst(
      real,
      (c) => mode == 'countries' && current.contains(c.id),
    );

    final query = ValueNotifier('');
    final result = await showModalBottomSheet<List<UpcomingDestinationDto>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AppSafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: AppText(
                              'Upcoming Destinations',
                              variant: AppTextVariant.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppButton(
                            label: 'Done',
                            variant: AppButtonVariant.text,
                            isExpanded: false,
                            onPressed: () {
                              if (mode == 'anywhere') {
                                Navigator.pop(
                                  ctx,
                                  <UpcomingDestinationDto>[],
                                );
                                return;
                              }
                              if (mode == 'none' && none != null) {
                                Navigator.pop(ctx, [
                                  UpcomingDestinationDto(
                                    id: none.id,
                                    name: none.country,
                                  ),
                                ]);
                                return;
                              }
                              Navigator.pop(
                                ctx,
                                [
                                  for (final c in real)
                                    if (current.contains(c.id))
                                      UpcomingDestinationDto(
                                        id: c.id,
                                        name: c.country,
                                      ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        maxLength: 20,
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                          counterText: '',
                        ),
                        onChanged: (v) {
                          query.value = v.toLowerCase();
                          setLocal(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ValueListenableBuilder<String>(
                        valueListenable: query,
                        builder: (context, q, _) {
                          final special = <(int, String, String)>[
                            (
                              anywhereId,
                              UpcomingDestinations.anywhereLabel,
                              '${UpcomingDestinations.openToAllLabel}',
                            ),
                            (
                              none?.id ?? -2,
                              UpcomingDestinations.noneName,
                              'No plans to travel',
                            ),
                          ];
                          final specialFiltered = q.isEmpty
                              ? special
                              : special
                                    .where(
                                      (e) =>
                                          e.$2.toLowerCase().contains(q) ||
                                          e.$3.toLowerCase().contains(q),
                                    )
                                    .toList();
                          final countriesFiltered = q.isEmpty
                              ? orderedCountries
                              : [
                                  for (final c in orderedCountries)
                                    if (c.country.toLowerCase().contains(q)) c,
                                ];

                          return ListView.builder(
                            itemCount:
                                specialFiltered.length +
                                countriesFiltered.length,
                            itemBuilder: (context, i) {
                              if (i < specialFiltered.length) {
                                final item = specialFiltered[i];
                                final isAnywhere = item.$1 == anywhereId;
                                final checked = isAnywhere
                                    ? mode == 'anywhere'
                                    : mode == 'none';
                                return ListTile(
                                  leading: Icon(
                                    isAnywhere
                                        ? Icons.public_rounded
                                        : Icons.block_rounded,
                                    color: checked
                                        ? AppColors.primary
                                        : null,
                                  ),
                                  title: AppText(item.$2),
                                  subtitle: AppText(
                                    item.$3,
                                    variant: AppTextVariant.caption,
                                  ),
                                  trailing: checked
                                      ? const Icon(
                                          Icons.check,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    setLocal(() {
                                      if (isAnywhere) {
                                        mode = 'anywhere';
                                        current = [];
                                      } else if (none != null) {
                                        mode = 'none';
                                        current = [];
                                      } else {
                                        AppToast.show(
                                          context,
                                          message:
                                              'None is unavailable right now. Try again shortly.',
                                        );
                                      }
                                    });
                                  },
                                );
                              }

                              final c =
                                  countriesFiltered[i - specialFiltered.length];
                              final checked =
                                  mode == 'countries' &&
                                  current.contains(c.id);
                              return CheckboxListTile(
                                value: checked,
                                activeColor: AppColors.primary,
                                title: AppText(c.country),
                                onChanged: (sel) {
                                  setLocal(() {
                                    mode = 'countries';
                                    if (sel == true) {
                                      if (current.length >= 5 &&
                                          !current.contains(c.id)) {
                                        AppToast.show(
                                          context,
                                          message: 'Limit is 5',
                                        );
                                        return;
                                      }
                                      if (!current.contains(c.id)) {
                                        current = [...current, c.id];
                                      }
                                    } else {
                                      current = List<int>.from(current)
                                        ..remove(c.id);
                                    }
                                    if (current.isEmpty) {
                                      mode = 'anywhere';
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    query.dispose();
    if (result == null) return;
    onChanged(result);
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: AppScaffold(
        title: 'Profile',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : _onBack,
        ),
        body: _loading
            ? const AppLoading(message: 'Loading profile…')
            : _error != null
            ? AppEmptyView(
                title: "Couldn't load profile",
                subtitle: _error,
                actionLabel: 'Retry',
                onAction: _load,
              )
            : Column(
                children: [
                  if (_saving)
                    LinearProgressIndicator(
                      minHeight: 3,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.14,
                      ),
                    ),
                  AppSlidingTabs(
                    controller: _tabController,
                    tabs: const [
                      AppSlidingTab(icon: Icons.edit_outlined, label: 'Edit'),
                      AppSlidingTab(
                        icon: Icons.visibility_outlined,
                        label: 'Preview',
                      ),
                    ],
                  ),
                  Expanded(
                    child: _tab == _EditTab.edit
                        ? _buildEditForm(theme)
                        : ExploreProfileCard(
                            key: ValueKey(
                              'preview-${_profile?.id}-'
                              '${_nameController.text}-'
                              '${_profile?.photos.length}',
                            ),
                            profile: _previewProfile(),
                            bottomInset: 100,
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEditForm(ThemeData theme) {
    final profile = _profile!;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _PhotoRow(
          photos: profile.photos,
          uploadingSlots: _uploadingSlots,
          onTapSlot: (i) {
            // Fill next empty slot, or replace an existing one.
            if (i < profile.photos.length) {
              _pickPhoto(i);
            } else {
              _pickPhoto(profile.photos.length);
            }
          },
        ),
        const SizedBox(height: 20),
        _SectionTitle('Status'),
        _PickerField(
          label: 'Current Country',
          value: profile.country?.country,
          hint: 'Tap to detect from location',
          trailing: _detectingCountry
              ? const Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.my_location_outlined, size: 20),
          onTap: _detectCountry,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: AppText(
            'Tap to detect your country from location',
            variant: AppTextVariant.caption,
            color: muted,
          ),
        ),
        _PickerField(
          label: 'Upcoming Destinations',
          value: UpcomingDestinations.displayLabel(
            profile.upcomingDestinations,
          ),
          hint: UpcomingDestinations.anywhereLabel,
          onTap: () async {
            await _pickUpcomingDestinations(
              selected: profile.upcomingDestinations.map((d) => d.id).toList(),
              onChanged: (destinations) {
                setState(() {
                  _profile = profile.copyWith(
                    upcomingDestinations: destinations,
                  );
                });
              },
            );
          },
        ),
        const SizedBox(height: 20),
        _SectionTitle('Basics'),
        AppTextField(
          controller: _nameController,
          label: 'Name',
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        if (_showAge) ...[
          AppAgePicker(
            value: profile.age,
            onChanged: (age) {
              setState(() {
                _profile = profile.copyWith(age: age);
                _dirty = true;
              });
            },
          ),
          const SizedBox(height: 14),
        ],
        AppTextField(
          controller: _occupationController,
          label: 'Occupation',
          hint: 'e.g. Marketing Manager',
          maxLength: 22,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        _PickerField(
          label: 'Lifestyle',
          value: labelForTravelStyle(profile.travelStyle),
          hint: 'e.g. Digital Nomad',
          onTap: () => _pickSingle(
            title: 'Lifestyle',
            options: [for (final o in signupTravelKindOptions) (o.$1, o.$2)],
            selected: profile.travelStyle ?? soloTravellerValue,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _profile = profile.copyWith(travelStyle: v);
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        _PickerField(
          label: 'Work flexibility',
          value: profile.mobility == null
              ? null
              : labelForMobility(profile.mobility!),
          hint: 'e.g. Fully Remote',
          onTap: () => _pickSingle(
            title: 'Work Flexibility',
            options: mobilityOptions,
            selected: profile.mobility,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _profile = profile.copyWith(mobility: v);
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        _PickerField(
          label: 'Nationality',
          value: profile.nationalities.isEmpty
              ? null
              : profile.nationalities.map((n) => n.name).join(', '),
          hint: 'e.g. American',
          onTap: () async {
            await _pickMultiInt(
              title: 'Nationality',
              items: _nationalities.map((n) => (n.id, n.name)).toList(),
              selected: profile.nationalities.map((n) => n.id).toList(),
              limit: 5,
              onChanged: (ids) {
                setState(() {
                  _profile = profile.copyWith(
                    nationalities: _nationalities
                        .where((n) => ids.contains(n.id))
                        .toList(),
                  );
                });
              },
            );
          },
        ),
        const SizedBox(height: 14),
        _PickerField(
          label: 'Languages',
          value: profile.languages.isEmpty
              ? null
              : profile.languages.map((l) => l.language).join(', '),
          hint: 'e.g. English',
          onTap: () async {
            await _pickMultiInt(
              title: 'Languages',
              items: _languages.map((l) => (l.id, l.language)).toList(),
              selected: profile.languages.map((l) => l.id).toList(),
              limit: 8,
              onChanged: (ids) {
                setState(() {
                  _profile = profile.copyWith(
                    languages: _languages
                        .where((l) => ids.contains(l.id))
                        .toList(),
                  );
                });
              },
            );
          },
        ),
        const SizedBox(height: 14),
        _PickerField(
          label: 'Orientation',
          value: labelForSexuality(profile.sexuality),
          hint: 'e.g. Straight',
          onTap: () => _pickSingle(
            title: 'Orientation',
            options: sexualityOptions,
            selected: profile.sexuality,
            allowNone: true,
            onChanged: (v) {
              setState(() {
                _profile = profile.copyWith(
                  sexuality: v,
                  clearSexuality: v == null,
                );
              });
            },
          ),
        ),
        // const SizedBox(height: 14),
        // _PickerField(
        //   label: 'Open to',
        //   value: profile.openTo.isEmpty
        //       ? null
        //       : labelsForOpenTo(profile.openTo),
        //   hint: 'e.g. Friends, Dating',
        //   onTap: () async {
        //     final next = await AppMultiSelectSheet.show<String>(
        //       context,
        //       title: 'Open to',
        //       items: [
        //         for (final o in openToOptions)
        //           AppMultiSelectItem(value: o.$2, label: o.$1),
        //       ],
        //       selected: profile.openTo,
        //     );
        //     if (next == null) return;
        //     setState(() {
        //       _profile = profile.copyWith(openTo: next);
        //     });
        //     _markDirty();
        //   },
        // ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _instagramController,
          label: 'Instagram',
          hint: 'e.g. @username',
          maxLength: 30,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 20),
        _SectionTitle('Story time'),
        AppTextArea(
          controller: _storyController,
          label: 'Most adventurous experience',
          hint: 'e.g. Moving to another country without knowing anyone',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        AppTextArea(
          controller: _wishesController,
          label: 'Top wishes',
          hint: 'e.g. open a cafe in Paris, buy my mom a house…',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        AppTextArea(
          controller: _doingNowController,
          label: "What I'm doing now",
          hint: 'e.g. travelling across Europe',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 20),
        _SectionTitle('Lists'),
        AppTextArea(
          controller: _valuesController,
          label: 'My values',
          hint: 'e.g. family, health, learning',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        AppTextArea(
          controller: _lovesController,
          label: 'Things I love',
          hint: 'e.g. fav hobbies, people, places, things',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: 14),
        AppTextArea(
          controller: _kindestController,
          label: "Kindest thing I've done",
          hint: 'e.g. helped a stranger find their way home',
          maxLength: 260,
          showInlineCounter: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _markDirty(),
        ),
      ],
    );
  }

  FullProfileDto _previewProfile() {
    final p = _profile!;
    final ig = _instagramController.text.trim();
    return FullProfileDto(
      id: p.id,
      name: _nameController.text.trim().isEmpty
          ? p.name
          : _nameController.text.trim(),
      profileType: p.profileType,
      photos: p.photos,
      isVerified: p.isVerified,
      status: p.status,
      country: p.country,
      age: p.age,
      occupation: _occupationController.text.trim(),
      mobility: p.mobility,
      storyTime: _storyController.text.trim(),
      upcomingDestinations: p.upcomingDestinations,
      nationalities: p.nationalities,
      languages: p.languages,
      topWishes: _wishesController.text.trim(),
      myValues: _valuesController.text.trim(),
      thingsILove: _lovesController.text.trim(),
      kindestThings: _kindestController.text.trim(),
      whatImDoingNow: _doingNowController.text.trim(),
      instagram: ig.isEmpty ? null : ig,
      travelStyle: p.travelStyle,
      motives: p.motives,
      sexuality: p.sexuality,
      openTo: p.openTo,
      totalKindness:
          AuthScope.of(context).profileMeta?.totalKindness ?? p.totalKindness,
    );
  }
}

bool _isNetworkUrl(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppText(
        title,
        variant: AppTextVariant.title,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.onTap,
    this.value,
    this.hint,
    this.trailing,
  });

  final String label;
  final String? value;
  final String? hint;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, variant: AppTextVariant.label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              suffixIcon:
                  trailing ??
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
            ),
            child: Text(
              hasValue ? value! : (hint ?? ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: hasValue ? null : theme.hintColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photos,
    required this.uploadingSlots,
    required this.onTapSlot,
  });

  final List<ProfilePhotoDto> photos;
  final Set<int> uploadingSlots;
  final ValueChanged<int> onTapSlot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _maxPhotos; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: _PhotoSlot(
                photo: i < photos.length ? photos[i] : null,
                uploading: uploadingSlots.contains(i),
                onTap: () => onTapSlot(i),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.photo,
    required this.uploading,
    required this.onTap,
  });

  final ProfilePhotoDto? photo;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = photo?.displayUrl ?? '';
    final hasPhoto = photo != null && url.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.45),
          ),
          color: hasPhoto
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.7,
                ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto && _isNetworkUrl(url))
                AppCachedImage(url: url, blurHash: photo?.blurHash)
              else if (hasPhoto)
                Image.file(File(url), fit: BoxFit.cover)
              else
                Icon(
                  Icons.add_a_photo_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              if (uploading)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (hasPhoto)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
