import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an ad / offer URL in a browser surface — never hands off to the
/// native Play Store / App Store via `externalApplication`.
///
/// Play Store deep links (`market://`, `play.google.com`) are rewritten to
/// HTTPS and opened in an in-app WebView so Android App Links don't jump to
/// the Play Store app.
Future<bool> openAdUrlInBrowser(String? rawUrl) async {
  final uri = _browserSafeUri(rawUrl);
  if (uri == null) {
    debugPrint('[Ads] openAdUrlInBrowser: invalid url=$rawUrl');
    return false;
  }

  final preferWebView = _isPlayOrAppStore(uri);
  final mode = preferWebView
      ? LaunchMode.inAppWebView
      : LaunchMode.inAppBrowserView;

  try {
    final launched = await launchUrl(
      uri,
      mode: mode,
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
    );
    if (launched) return true;
  } catch (e) {
    debugPrint('[Ads] $mode failed for $uri: $e');
  }

  // Fallback: in-app browser view (Custom Tabs / SFSafariViewController).
  try {
    return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (e) {
    debugPrint('[Ads] inAppBrowserView fallback failed for $uri: $e');
    return false;
  }
}

Uri? _browserSafeUri(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return null;

  // market://details?id=com.example → https Play Store listing (web).
  if (parsed.scheme == 'market') {
    final id = parsed.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    return Uri.https('play.google.com', '/store/apps/details', {'id': id});
  }

  // itms-apps / itms → https App Store web listing when possible.
  if (parsed.scheme == 'itms-apps' || parsed.scheme == 'itms') {
    final id =
        parsed.queryParameters['id'] ??
        (parsed.pathSegments.isNotEmpty ? parsed.pathSegments.last : null);
    if (id != null && id.isNotEmpty) {
      return Uri.https('apps.apple.com', '/app/id$id');
    }
  }

  if (parsed.hasScheme) return parsed;
  return Uri.tryParse('https://$trimmed');
}

bool _isPlayOrAppStore(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == 'play.google.com' ||
      host == 'play.app.goo.gl' ||
      host.endsWith('app.goo.gl') ||
      host == 'apps.apple.com' ||
      host == 'itunes.apple.com';
}
