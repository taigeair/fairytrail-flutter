import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';

/// Local signup draft helpers (includes UI-only fields).
abstract final class SignupDraft {
  static Future<Map<String, dynamic>> load() async {
    return Map<String, dynamic>.from(
      await LocalStorage.instance.getRegistrationData() ?? {},
    );
  }

  static Future<void> save(Map<String, dynamic> data) async {
    await LocalStorage.instance.setRegistrationData(data);
  }

  static Future<void> merge(Map<String, dynamic> patch) async {
    final data = await load();
    data.addAll(patch);
    await save(data);
  }

  static RegistrationRequest toRegistrationRequest(
    Map<String, dynamic> data, {
    String? email,
    Map<String, dynamic>? deviceMetadata,
  }) {
    return RegistrationRequest(
      name: (data['name'] as String?)?.trim() ?? '',
      profileType: (data['profileType'] as String?) ?? '',
      mobility: (data['mobility'] as String?) ?? 'non-remote',
      storyTime: (data['storyTime'] as String?) ?? '',
      email: email,
      age: (data['age'] as num?)?.toInt(),
      deviceMetadata: deviceMetadata ?? const {},
    );
  }
}
