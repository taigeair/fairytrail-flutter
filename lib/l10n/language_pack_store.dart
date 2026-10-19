import 'dart:convert';

import 'package:fairytrail/l10n/language_models.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/services.dart';

/// Bundled + on-disk language packs.
///
/// Remote packs are kept until the catalog reports a higher
/// [LanguageInfo.version] — then the cached pack is cleared and re-downloaded.
class LanguagePackStore {
  LanguagePackStore._();

  static final LanguagePackStore instance = LanguagePackStore._();

  static const _bundledCatalogAsset = 'assets/l10n/catalog.json';

  String _packAsset(String code) => 'assets/l10n/$code.json';

  String _packStorageKey(String code) => '${StorageKeys.l10nPackPrefix}$code';

  Future<LanguageCatalog> loadBundledCatalog() async {
    final raw = await rootBundle.loadString(_bundledCatalogAsset);
    return LanguageCatalog.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<LanguageCatalog?> loadCachedCatalog() async {
    final json = await LocalStorage.instance.getJson(StorageKeys.l10nCatalog);
    if (json == null) return null;
    return LanguageCatalog.fromJson(json);
  }

  Future<void> saveCatalog(LanguageCatalog catalog) async {
    await LocalStorage.instance.setJson(
      StorageKeys.l10nCatalog,
      catalog.toJson(),
    );
  }

  Future<LanguagePack> loadBundledPack(String code) async {
    final raw = await rootBundle.loadString(_packAsset(code));
    return LanguagePack.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<LanguagePack?> loadCachedPack(String code) async {
    final json = await LocalStorage.instance.getJson(_packStorageKey(code));
    if (json == null) return null;
    return LanguagePack.fromJson(json);
  }

  Future<void> savePack(LanguagePack pack) async {
    await LocalStorage.instance.setJson(
      _packStorageKey(pack.code),
      pack.toJson(),
    );
  }

  /// Drop a cached pack so the next sync re-downloads it.
  Future<void> clearPack(String code) async {
    await LocalStorage.instance.remove(_packStorageKey(code));
  }

  /// Drop every cached pack (catalog kept). Used when [catalogVersion] jumps.
  Future<void> clearAllPacks(Iterable<String> codes) async {
    for (final code in codes) {
      await clearPack(code);
    }
  }

  /// Same-code pack only (cached or bundled). Never falls back to another locale.
  Future<LanguagePack?> resolvePackSameCode(String code) async {
    final cached = await loadCachedPack(code);
    LanguagePack? bundled;
    try {
      bundled = await loadBundledPack(code);
    } catch (_) {}

    if (cached != null && bundled != null) {
      return bundled.version > cached.version ? bundled : cached;
    }
    return cached ?? bundled;
  }

  /// Prefer the highest version among cached + bundled for [code].
  /// Falls back to English strings only when that locale is missing locally.
  Future<LanguagePack> resolvePack(String code) async {
    final same = await resolvePackSameCode(code);
    if (same != null) return same;

    if (code != 'en') {
      final en = await resolvePackSameCode('en');
      if (en != null) return en;
    }
    throw StateError('Missing language pack for $code');
  }
}
