import 'package:fairytrail/api/travel.dart' as travel_api;
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

PageRoute<T> _bottomSheetPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: true,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
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

/// RN `/main/modal/pickup-travelmoney` — free $1 trail money pickup.
///
/// Pickup and success share this screen. Countdown is advanced by Explore
/// before opening (RN updates on mount) so local meta matches the next server
/// checkpoint and the modal does not loop.
class PickupTravelMoneyScreen extends StatefulWidget {
  const PickupTravelMoneyScreen({super.key, required this.totalActions});

  final int totalActions;

  /// Returns `true` if the user picked up money, else `false`.
  static Future<bool> open(
    BuildContext context, {
    required int totalActions,
  }) async {
    final result = await Navigator.of(context, rootNavigator: true).push<bool>(
      _bottomSheetPageRoute<bool>(
        builder: (_) => PickupTravelMoneyScreen(totalActions: totalActions),
      ),
    );
    return result ?? false;
  }

  @override
  State<PickupTravelMoneyScreen> createState() =>
      _PickupTravelMoneyScreenState();
}

class _PickupTravelMoneyScreenState extends State<PickupTravelMoneyScreen> {
  static const _kFade = Duration(milliseconds: 350);

  bool _loading = false;
  bool _success = false;

  Future<void> _pickUp() async {
    if (_loading || _success) return;
    setState(() => _loading = true);
    try {
      await travel_api.addFreeTravelMoney();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _success = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  /// Crossfades copy while sizing to the success text so layout never jumps.
  Widget _fadingCopy({
    required String pickup,
    required String success,
    required AppTextVariant variant,
    FontWeight? fontWeight,
    required double fontSize,
  }) {
    Widget copy(String value) => AppText(
          value,
          variant: variant,
          textAlign: TextAlign.center,
          fontWeight: fontWeight,
          fontSize: fontSize,
        );

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AnimatedOpacity(
          opacity: _success ? 1 : 0,
          duration: _kFade,
          curve: Curves.easeInOut,
          child: copy(success),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _success ? 0 : 1,
            duration: _kFade,
            curve: Curves.easeInOut,
            child: copy(pickup),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _fadingCopy(
                        pickup: 'Woah',
                        success: "You've stashed the\ntrail money!",
                        variant: AppTextVariant.title,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                      const SizedBox(height: 30),
                      _fadingCopy(
                        pickup: 'You found \$1 on\nthe trail',
                        success:
                            'Use these funds in\nthe Fairytrail gift shop',
                        variant: AppTextVariant.body,
                        fontSize: 22,
                      ),
                      const SizedBox(height: 30),
                      Image.asset(
                        'assets/travel/money.png',
                        width: 145,
                        height: 145,
                        filterQuality: FilterQuality.medium,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: _kFade,
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: AppButton(
                  key: ValueKey(_success),
                  label: _success ? 'Continue' : 'Pick up trail money',
                  isLoading: _loading,
                  onPressed: _success
                      ? () => Navigator.of(context).pop(true)
                      : _pickUp,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedOpacity(
                opacity: _success ? 0 : 1,
                duration: _kFade,
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _success || _loading,
                  child: AppButton(
                    label: 'Leave it',
                    variant: AppButtonVariant.text,
                    onPressed: () => Navigator.of(context).pop(false),
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
