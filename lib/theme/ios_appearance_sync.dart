import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Syncs the in-app theme to iOS `UIUserInterfaceStyle`.
///
/// Popular apps do this so third-party keyboards (Gboard, etc.) follow the
/// **app** theme instead of the system Appearance setting. Apps cannot force
/// Apple's keyboard over Gboard — that is a user/system choice.
class IosAppearanceSync {
  IosAppearanceSync._();

  static const _channel = MethodChannel('fairytrail/appearance');

  static Future<void> sync(ThemeMode mode) async {
    if (kIsWeb || !Platform.isIOS) return;

    final style = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    try {
      await _channel.invokeMethod<void>('setUserInterfaceStyle', style);
    } catch (e) {
      debugPrint('[IosAppearanceSync] failed: $e');
    }
  }
}
