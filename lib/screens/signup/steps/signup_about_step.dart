import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 4 — tell us about yourself (storyTime). Optional / skippable.
class SignupAboutStep extends StatefulWidget {
  const SignupAboutStep({
    super.key,
    required this.initialStory,
    required this.onChanged,
    required this.onContinue,
    required this.onSkip,
    this.isLoading = false,
    this.error,
  });

  final String initialStory;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final bool isLoading;
  final String? error;

  @override
  State<SignupAboutStep> createState() => _SignupAboutStepState();
}

class _SignupAboutStepState extends State<SignupAboutStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialStory);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);

    return SignupStepScaffold(
      step: 12,
      title: 'One last thing',
      subtitle: 'Tell us of your adventure, brave explorer!',
      canContinue: _controller.text.trim().isNotEmpty,
      isLoading: widget.isLoading,
      onContinue: widget.onContinue,
      secondaryLabel: 'Skip for now',
      onSecondary: widget.onSkip,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.error != null) ...[
              AppText(
                widget.error!,
                variant: AppTextVariant.bodySmall,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
            ],
            AppText(
              'Most adventurous experience',
              variant: AppTextVariant.label,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
            const SizedBox(height: 10),
            AppTextArea(
              controller: _controller,
              hint: 'e.g. Hitchhiked across Iceland with strangers ...',
              minLines: 5,
              maxLines: 8,
              maxLength: 260,
              textCapitalization: TextCapitalization.sentences,
              enabled: !widget.isLoading,
              onChanged: (v) {
                widget.onChanged(v);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
