import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fairytrail/widgets/widgets.dart';

/// Full-screen first-run overlay (RN `fake-connect-intro`).
///
/// Shows the connect intro art; any tap dismisses. Cleared on logout/login so
/// it appears again each time the user signs in.
///
/// When [onDone] is set (shell gate), dismiss calls it instead of popping a route.
class FakeConnectIntroScreen extends StatefulWidget {
  const FakeConnectIntroScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  /// Phone/phablet only — matches RN skip for iPad / tablet.
  static bool shouldSkipForDevice(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  @override
  State<FakeConnectIntroScreen> createState() => _FakeConnectIntroScreenState();
}

class _FakeConnectIntroScreenState extends State<FakeConnectIntroScreen> {
  @override
  void initState() {
    super.initState();
    LocalStorage.instance.setHasSeenFakeConnectIntro();
  }

  void _dismiss() {
    HapticsService.selection();
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(1, 1, 1, 1),
              child: Center(
                child: Image.asset(
                  'assets/explore/introConnect.jpg',
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
