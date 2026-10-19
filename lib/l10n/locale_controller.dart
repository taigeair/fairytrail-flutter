import 'dart:async';

import 'package:fairytrail/l10n/language_api.dart';
import 'package:fairytrail/l10n/language_models.dart';
import 'package:fairytrail/l10n/language_pack_store.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Built-in locales shipped with the app. Extra codes can arrive via the API.
const List<String> kBundledLanguageCodes = ['en', 'es', 'hi'];

/// Holds active locale + string table. Defaults to the OS language when it is
/// a bundled/catalog language; otherwise English. User override is persisted.
///
/// ## Version control
/// Server files carry versions:
/// - `catalog.json` → `catalogVersion` (bump when languages are added/removed)
/// - `{code}.json` + catalog entry → `version` (bump when that pack’s strings change)
///
/// On sync the app fetches the catalog, compares versions, clears outdated
/// cached packs, and re-downloads only what changed.
class LocaleController extends ChangeNotifier {
  LocaleController({LanguagePackStore? store})
    : _store = store ?? LanguagePackStore.instance;

  final LanguagePackStore _store;

  Locale _locale = const Locale('en');
  Map<String, String> _strings = const {};

  /// English fallback table so missing keys in other packs never show raw keys.
  Map<String, String> _englishFallback = const {};
  LanguageCatalog _catalog = const LanguageCatalog(
    catalogVersion: 0,
    languages: [
      LanguageInfo(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        version: 1,
      ),
      LanguageInfo(
        code: 'es',
        name: 'Spanish',
        nativeName: 'Español',
        version: 1,
      ),
      LanguageInfo(
        code: 'hi',
        name: 'Hindi',
        nativeName: 'हिन्दी',
        version: 1,
      ),
    ],
  );

  /// `null` = follow system.
  String? _userLanguageCode;
  bool _ready = false;
  bool _syncing = false;
  bool _updatingPack = false;

  bool get isReady => _ready;
  bool get isUpdatingPack => _updatingPack;
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  LanguageCatalog get catalog => _catalog;
  List<Locale> get supportedLocales => _catalog.languages
      .map((l) => Locale(l.code))
      .toList(growable: false);

  /// Display name for the active language (native name preferred).
  String get currentLanguageLabel {
    final info = _catalog.find(languageCode);
    return info?.nativeName ?? languageCode;
  }

  Future<void> bootstrap() async {
    _userLanguageCode = await LocalStorage.instance.getAppLanguageCode();
    final cachedCatalog = await _store.loadCachedCatalog();
    if (cachedCatalog != null && cachedCatalog.languages.isNotEmpty) {
      _catalog = cachedCatalog;
    } else {
      try {
        _catalog = await _store.loadBundledCatalog();
      } catch (e) {
        debugPrint('[L10n] bundled catalog missing: $e');
      }
    }

    final code = _resolveActiveCode();
    final enPack = await _store.resolvePack('en');
    _englishFallback = enPack.strings;
    await _applyPack(code);
    _ready = true;
    notifyListeners();

    // Background: check catalog/pack versions and refresh outdated caches.
    unawaited(syncRemoteIfNeeded());
  }

  /// Look up a string. Falls back to English pack, then the key itself.
  String t(String key, [Map<String, String>? params]) {
    var value = _strings[key];
    if (value == null || value.isEmpty) {
      value = _englishFallback[key];
    }
    if (value == null || value.isEmpty) {
      value = key;
    }
    if (params != null) {
      params.forEach((name, replacement) {
        value = value!.replaceAll('{$name}', replacement);
      });
    }
    return value!;
  }

  /// True when there is no local pack, or catalog reports a newer version.
  Future<bool> packNeedsRemoteFetch(String code) async {
    final normalized = code.toLowerCase();
    final info = _catalog.find(normalized);
    final local = await _store.resolvePackSameCode(normalized);
    if (local == null) return true;
    if (info != null && local.version < info.version) return true;
    return false;
  }

  /// Switch UI to cached/bundled strings immediately (no network).
  Future<void> applyLanguageLocally(String code) async {
    final normalized = code.toLowerCase();
    if (_userLanguageCode == normalized && languageCode == normalized) return;

    _userLanguageCode = normalized;
    await LocalStorage.instance.setAppLanguageCode(normalized);
    await _applyPack(normalized);
    notifyListeners();
  }

  /// Download/update the active language pack. Call only when
  /// [packNeedsRemoteFetch] is true (shows loading UI once in the picker).
  Future<void> downloadLanguagePack(String code) async {
    final normalized = code.toLowerCase();
    _updatingPack = true;
    notifyListeners();
    try {
      await _ensurePackDownloaded(normalized, force: true);
      if (_userLanguageCode == normalized) {
        await _applyPack(normalized);
      }
    } finally {
      _updatingPack = false;
      notifyListeners();
    }
  }

  /// Apply local pack first; download only when outdated/missing.
  /// Returns `true` if a remote fetch ran (for one-time loading UI).
  Future<bool> setLanguageCode(String code) async {
    final normalized = code.toLowerCase();
    final needsFetch = await packNeedsRemoteFetch(normalized);
    await applyLanguageLocally(normalized);

    if (!needsFetch) {
      unawaited(_ensurePackDownloaded(normalized));
      return false;
    }

    await downloadLanguagePack(normalized);
    return true;
  }

  /// Refresh catalog when the picker opens (background). Same version rules.
  Future<void> refreshCatalogForPicker() => syncRemoteIfNeeded(force: true);

  /// Fetches the remote catalog and re-downloads packs whose `version` increased.
  ///
  /// - Pack files are **not** re-fetched when versions match (cache kept).
  /// - When `catalogVersion` increases, all cached packs are cleared first.
  /// - When a language’s `version` increases, only that pack is cleared + fetched.
  Future<void> syncRemoteIfNeeded({bool force = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final cachedCatalog = await _store.loadCachedCatalog();
      LanguageCatalog remote;
      try {
        remote = await LanguageApi.fetchCatalog();
        if (remote.languages.isEmpty) return;
      } catch (e) {
        debugPrint('[L10n] catalog sync skipped: $e');
        return;
      }

      final catalogBumped =
          cachedCatalog == null ||
          remote.catalogVersion > cachedCatalog.catalogVersion;

      if (catalogBumped) {
        // Whole catalog changed — drop every known pack cache.
        final codes = <String>{
          ...remote.languages.map((l) => l.code),
          ...?cachedCatalog?.languages.map((l) => l.code),
          ...kBundledLanguageCodes,
        };
        await _store.clearAllPacks(codes);
        debugPrint(
          '[L10n] catalogVersion ${cachedCatalog?.catalogVersion ?? 0} → '
          '${remote.catalogVersion}; cleared pack caches',
        );
      } else {
        // Same catalog generation — clear only languages whose pack version rose.
        for (final lang in remote.languages) {
          final cached = await _store.loadCachedPack(lang.code);
          if (cached != null && cached.version < lang.version) {
            await _store.clearPack(lang.code);
            debugPrint(
              '[L10n] ${lang.code} pack ${cached.version} → ${lang.version}; '
              'cleared cache',
            );
          }
        }
      }

      _catalog = remote;
      await _store.saveCatalog(remote);

      final code = _resolveActiveCode();
      await _ensurePackDownloaded(code, catalog: remote, force: force);

      // Keep English fallback fresh if its version bumped.
      if (code != 'en') {
        await _ensurePackDownloaded('en', catalog: remote);
        final en = await _store.loadCachedPack('en');
        if (en != null) _englishFallback = en.strings;
      }

      if (code == languageCode) {
        await _applyPack(code);
      }
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _ensurePackDownloaded(
    String code, {
    LanguageCatalog? catalog,
    bool force = false,
  }) async {
    final cat = catalog ?? _catalog;
    final info = cat.find(code);
    final cached = await _store.loadCachedPack(code);
    if (!force &&
        cached != null &&
        (info == null || cached.version >= info.version)) {
      return;
    }

    try {
      final pack = await LanguageApi.fetchPack(code);
      // Compare only against the same locale — never against English fallback.
      final existing = await _store.resolvePackSameCode(code);
      if (existing != null && pack.version < existing.version) {
        debugPrint(
          '[L10n] skip older remote $code pack '
          '${pack.version} < local ${existing.version}',
        );
        return;
      }
      await _store.savePack(pack);
      if (code == languageCode || code == _userLanguageCode) {
        _strings = pack.strings;
        _locale = Locale(pack.code);
      }
    } catch (e) {
      debugPrint('[L10n] pack download skipped ($code): $e');
    }
  }

  String _resolveActiveCode() {
    final user = _userLanguageCode?.toLowerCase();
    if (user != null && user.isNotEmpty) {
      if (_isSupported(user)) return user;
    }
    return _systemPreferredCode();
  }

  String _systemPreferredCode() {
    final system = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (_isSupported(system)) return system;
    return 'en';
  }

  bool _isSupported(String code) {
    if (_catalog.find(code) != null) return true;
    return kBundledLanguageCodes.contains(code);
  }

  Future<void> _applyPack(String code) async {
    final same = await _store.resolvePackSameCode(code);
    if (same != null) {
      _locale = Locale(same.code);
      _strings = same.strings;
      return;
    }
    // Keep the requested locale even when strings temporarily fall back to EN.
    final fallback = await _store.resolvePack('en');
    _locale = Locale(code);
    _strings = fallback.strings;
  }
}

/// Provides [LocaleController] down the tree.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope not found in widget tree');
    return scope!.notifier!;
  }

  static LocaleController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
  }
}

extension L10nX on BuildContext {
  LocaleController get l10n => LocaleScope.of(this);

  String tr(String key, [Map<String, String>? params]) =>
      LocaleScope.of(this).t(key, params);
}
