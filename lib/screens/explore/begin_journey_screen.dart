import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/explore/begin_journey_prefs.dart';
import 'package:fairytrail/explore/explore_warm_prefetch.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// RN `/main/explore/match-with` — first-run prefs seed before Explore.
///
/// Prefs + profile prefetch are usually already warmed after location
/// ([ExploreWarmPrefetch]). The button then just continues.
class BeginJourneyScreen extends StatefulWidget {
  const BeginJourneyScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<BeginJourneyScreen> createState() => _BeginJourneyScreenState();
}

class _BeginJourneyScreenState extends State<BeginJourneyScreen> {
  bool _loading = false;

  Future<void> _onBegin() async {
    if (_loading) return;
    setState(() => _loading = true);

    final auth = AuthScope.of(context);
    final meta = auth.profileMeta;

    // Warm prefetch already seeded prefs, or returning user.
    if (ExploreWarmPrefetch.instance.prefsSeeded ||
        (meta != null && meta.matchWithCount >= 1)) {
      try {
        await auth.refreshMe();
      } catch (_) {}
      if (!mounted) return;
      widget.onDone();
      return;
    }

    try {
      await seedBeginJourneyPrefsIfNeeded(meta);
      if (!mounted) return;
      try {
        await auth.refreshMe();
      } catch (_) {}
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppSafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: AppText(
                  'Adventure awaits! Ready to make new friends and explore the world? 🌍✨',
                  variant: AppTextVariant.headline,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const Spacer(flex: 2),
              AppButton(
                label: 'Begin Journey',
                isLoading: _loading,
                onPressed: _onBegin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
