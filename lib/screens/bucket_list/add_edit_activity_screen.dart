import 'dart:io';

import 'package:fairytrail/api/activities.dart';
import 'package:fairytrail/api/models/activity_models.dart';
import 'package:fairytrail/api/models/explore_models.dart';
import 'package:fairytrail/api/profile_photos.dart';
import 'package:fairytrail/screens/bucket_list/activity_added_screen.dart';
import 'package:fairytrail/screens/shell/shell_chrome.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/image_pick_crop.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class _CountryPick {
  const _CountryPick.clear() : country = null;
  const _CountryPick.value(this.country);

  final CountryDto? country;
}

class AddEditActivityScreen extends StatefulWidget {
  const AddEditActivityScreen({super.key, this.activity, this.chrome});

  final ActivityDto? activity;
  final ShellChromeController? chrome;

  static Future<ActivityDto?> open(
    BuildContext context, {
    ActivityDto? activity,
  }) {
    final chrome = ShellChromeScope.maybeOf(context);
    return Navigator.of(context).push<ActivityDto>(
      MaterialPageRoute(
        builder: (_) =>
            AddEditActivityScreen(activity: activity, chrome: chrome),
      ),
    );
  }

  @override
  State<AddEditActivityScreen> createState() => _AddEditActivityScreenState();
}

class _AddEditActivityScreenState extends State<AddEditActivityScreen> {
  final _nameController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<CountryDto> _countries = [];
  CountryDto? _country;
  String? _attachmentId;
  String? _localPhotoPath;
  String? _remotePhotoUrl;

  bool get _isEdit => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    if (a != null) {
      _nameController.text = a.name;
      _country = a.country;
      _attachmentId = a.photo.attachmentId;
      _remotePhotoUrl = a.photo.url;
    }
    _loadProps();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProps() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final props = await getAddActivityProps();
      if (!mounted) return;
      setState(() {
        _countries = props.countries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = serverErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AppSafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const AppText('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const AppText('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await pickAndCropSquareImage(source: source);
    if (file == null || !mounted) return;

    setState(() {
      _localPhotoPath = file.path;
      _error = null;
    });
  }

  Future<String> _uploadLocalPhoto() async {
    final path = _localPhotoPath;
    if (path == null) {
      throw StateError('No local photo to upload');
    }
    final signed = await createAttachment(filename: 'activity.jpg');
    final bytes = await File(path).readAsBytes();
    await uploadBytesToSignedUrl(uploadUrl: signed.uploadUrl, bytes: bytes);
    return signed.attachmentId;
  }

  Future<void> _pickCountry() async {
    final query = ValueNotifier('');
    final result = await showModalBottomSheet<_CountryPick>(
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
                              'Country (optional)',
                              variant: AppTextVariant.title,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          AppButton(
                            label: 'None',
                            variant: AppButtonVariant.text,
                            isExpanded: false,
                            onPressed: () =>
                                Navigator.pop(ctx, const _CountryPick.clear()),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
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
                          final filtered = q.isEmpty
                              ? _countries
                              : _countries
                                    .where(
                                      (c) =>
                                          c.country.toLowerCase().contains(q),
                                    )
                                    .toList();
                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final c = filtered[index];
                              final selected = _country?.id == c.id;
                              return ListTile(
                                title: AppText(c.country),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () =>
                                    Navigator.pop(ctx, _CountryPick.value(c)),
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
    if (!mounted || result == null) return;
    setState(() => _country = result.country);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final hasPhoto =
        _localPhotoPath != null ||
        (_attachmentId != null && _attachmentId!.isNotEmpty);
    if (!hasPhoto) {
      AppToast.show(
        context,
        message: 'Please add an image for your activity.',
      );
      return;
    }
    if (name.isEmpty) {
      AppToast.show(context, message: 'Please enter activity name.');
      return;
    }

    setState(() => _saving = true);
    try {
      final attachmentId = _localPhotoPath != null
          ? await _uploadLocalPhoto()
          : _attachmentId!;

      if (_isEdit) {
        final updated = await editActivity(
          id: widget.activity!.id,
          attachmentId: attachmentId,
          name: name,
          countryId: _country?.id,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      } else {
        final created = await addActivity(
          attachmentId: attachmentId,
          name: name,
          countryId: _country?.id,
        );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ActivityAddedScreen(activity: created),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Could not save your activity. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _browseIdeas() {
    Navigator.of(context).pop();
    widget.chrome?.browseActivityIdeas();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final imageDimension = screenSize.shortestSide >= 600
        ? screenSize.width * 0.66
        : 280.0;

    return AppScaffold(
      title: _isEdit ? 'Edit Activity' : 'Add Activity',
      actions: _isEdit
          ? null
          : [
              TextButton(
                onPressed: _saving ? null : _browseIdeas,
                child: const Text('Browse ideas'),
              ),
            ],
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              children: [
                if (_error != null) ...[
                  AppText(
                    _error!,
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: _saving ? null : _pickPhoto,
                    child: SizedBox.square(
                      dimension: imageDimension,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_localPhotoPath != null)
                              Image.file(
                                File(_localPhotoPath!),
                                fit: BoxFit.cover,
                              )
                            else if (_remotePhotoUrl != null)
                              AppCachedImage(url: _remotePhotoUrl!)
                            else
                              ColoredBox(
                                color: AppColors.chipTagBgOf(context),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 40,
                                      color: AppColors.textSecondaryOf(
                                        context,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    AppText(
                                      'Add photo',
                                      variant: AppTextVariant.label,
                                      color: AppColors.textSecondaryOf(
                                        context,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _nameController,
                  label: 'Bucket list activity name',
                  hint: 'e.g. Swimming in the Great Barrier Reef',
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                AppText(
                  'Country (optional)',
                  variant: AppTextVariant.label,
                ),
                const SizedBox(height: 8),
                AppCard(
                  onTap: _pickCountry,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          _country?.country ?? 'e.g. Australia',
                          color: _country == null
                              ? Theme.of(context).hintColor
                              : null,
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Save',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Discard',
                  variant: AppButtonVariant.secondary,
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  AppText(
                    'Please add one activity at a time.',
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.textSecondaryOf(context),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
