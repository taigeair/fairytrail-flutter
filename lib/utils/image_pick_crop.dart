import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Pick an image, then square-crop (RN `cropPickerAssetToSquare` parity).
///
/// Returns `null` if the user cancels the picker or the cropper.
Future<XFile?> pickAndCropSquareImage({
  required ImageSource source,
  int compressQuality = 92,
}) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 100,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: compressQuality,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop',
        toolbarColor: AppColors.primary,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: AppColors.primary,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
        hideBottomControls: false,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop',
        doneButtonTitle: 'Next',
        cancelButtonTitle: 'Cancel',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
        aspectRatioPickerButtonHidden: true,
        rotateButtonsHidden: false,
        aspectRatioPresets: const [CropAspectRatioPreset.square],
      ),
    ],
  );

  if (cropped == null) return null;
  return XFile(cropped.path);
}
