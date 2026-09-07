import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fairytrail/widgets/widgets.dart';

PageRoute<bool> _slideUpRoute({required WidgetBuilder builder}) {
  return PageRouteBuilder<bool>(
    fullscreenDialog: true,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );
      return SlideTransition(position: offset, child: child);
    },
  );
}

bool _isPopupCloseUri(Uri uri) {
  if (uri.scheme == 'fairytrail' &&
      (uri.host == 'popup' || uri.pathSegments.contains('popup'))) {
    return uri.path.contains('close') || uri.host == 'close';
  }
  return false;
}

/// Fullscreen announcement webview (remote `show_admin_popup_*`).
///
/// Public URL — no auth headers. Shown once per [version] after login.
/// Web pages can close via JS channel `FairytrailPopup.postMessage('close')`
/// or by navigating to `fairytrail://popup/close`.
class AdminPopupWebViewScreen extends StatefulWidget {
  const AdminPopupWebViewScreen({
    super.key,
    required this.url,
    required this.version,
  });

  final String url;
  final int version;

  /// Opens if remote config allows and this [version] has not been seen
  /// for [userId]. Marks the version seen only after the popup is explicitly
  /// closed, so an interrupted view can be shown again.
  static Future<void> maybeShow(
    BuildContext context, {
    required String? userId,
    required bool enabled,
    required int version,
    required String? url,
  }) async {
    final uid = userId?.trim() ?? '';
    final trimmed = url?.trim();
    if (uid.isEmpty ||
        !enabled ||
        version <= 0 ||
        trimmed == null ||
        trimmed.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return;
    }

    if (!LocalStorage.instance.hadInitiatedConnectAtSessionStart) {
      return;
    }

    final seen = await LocalStorage.instance.getLastSeenAdminPopupVersion(uid);
    if (seen >= version) return;
    if (!context.mounted) return;

    final closed = await Navigator.of(context, rootNavigator: true).push<bool>(
      _slideUpRoute(
        builder: (_) => AdminPopupWebViewScreen(url: trimmed, version: version),
      ),
    );
    if (closed == true) {
      await LocalStorage.instance.setLastSeenAdminPopupVersion(uid, version);
    }
  }

  @override
  State<AdminPopupWebViewScreen> createState() =>
      _AdminPopupWebViewScreenState();
}

class _AdminPopupWebViewScreenState extends State<AdminPopupWebViewScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _closing = false;

  void _closePopup() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FairytrailPopup',
        onMessageReceived: (message) {
          final msg = message.message.trim().toLowerCase();
          if (msg == 'close' || msg == 'done') {
            _closePopup();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isPopupCloseUri(uri)) {
              _closePopup();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.backgroundOf(context);

    return Scaffold(
      backgroundColor: bg,
      body: AppSafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Close',
                onPressed: _closePopup,
                icon: Icon(
                  Icons.close,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
