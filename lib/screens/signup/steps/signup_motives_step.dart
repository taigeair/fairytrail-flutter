import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:flutter/material.dart';

/// Step 2 — what brings you to Fairytrail (persisted as profile motives).
class SignupMotivesStep extends StatefulWidget {
  const SignupMotivesStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onContinue,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onContinue;

  @override
  State<SignupMotivesStep> createState() => _SignupMotivesStepState();
}

class _SignupMotivesStepState extends State<SignupMotivesStep> {
  /// Checked options first when the step opens; toggles do not reorder.
  late final List<(String, String)> _ordered = selectedFirst(
    signupMotiveOptions,
    (opt) => widget.selected.contains(opt.$2),
  );

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      step: 2,
      title: 'What brings you here?',
      subtitle: 'Pick all that apply — this helps personalize your experience',
      canContinue: widget.selected.isNotEmpty,
      onContinue: widget.onContinue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          for (final opt in _ordered) ...[
            SignupOptionTile(
              label: opt.$1,
              selected: widget.selected.contains(opt.$2),
              icon: switch (opt.$2) {
                'travel_buddy' => Icons.hiking_rounded,
                'meet_nearby' => Icons.location_on_outlined,
                'new_friends' => Icons.coffee,
                'romantic_partner' => Icons.favorite_outline_rounded,
                'trips_adventures' => Icons.explore_outlined,
                'plan_trips' => Icons.bookmark_border_rounded,
                _ => Icons.favorite_outline_rounded,
              },
              onTap: () {
                final next = Set<String>.from(widget.selected);
                if (next.contains(opt.$2)) {
                  next.remove(opt.$2);
                } else {
                  next.add(opt.$2);
                }
                widget.onChanged(next);
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
