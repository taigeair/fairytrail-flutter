import 'package:fairytrail/components/registration/profile_type_selector.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 1 — age, name, gender.
class SignupBasicsStep extends StatefulWidget {
  const SignupBasicsStep({
    super.key,
    required this.initialName,
    required this.initialProfileType,
    required this.initialAge,
    required this.onChanged,
    required this.onContinue,
    this.isLoading = false,
    this.error,
  });

  final String initialName;
  final String? initialProfileType;
  final int? initialAge;
  final void Function({String? name, String? profileType, int? age}) onChanged;
  final VoidCallback onContinue;
  final bool isLoading;
  final String? error;

  @override
  State<SignupBasicsStep> createState() => _SignupBasicsStepState();
}

class _SignupBasicsStepState extends State<SignupBasicsStep> {
  late final TextEditingController _nameController;
  String? _profileType;
  int? _age;

  bool get _canContinue {
    final nameOk = _nameController.text.trim().isNotEmpty;
    final typeOk = _profileType != null;
    final ageOk = _age != null && _age! >= 18 && _age! <= 150;
    return nameOk && typeOk && ageOk;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _profileType = widget.initialProfileType;
    _age = widget.initialAge;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      name: _nameController.text.trim(),
      profileType: _profileType,
      age: _age,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepScaffold(
      step: 1,
      title: 'About you',
      subtitle: 'Tell us the basics so travelers know who you are',
      canContinue: _canContinue,
      isLoading: widget.isLoading,
      onContinue: widget.onContinue,
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
            AppTextField(
              controller: _nameController,
              label: 'Name',
              hint: 'Your name',
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 20),
            ProfileTypeSelector(
              value: _profileType,
              onChanged: (v) {
                _profileType = v;
                _emit();
              },
            ),
            const SizedBox(height: 20),
            AppAgePicker(
              value: _age,
              onChanged: (age) {
                _age = age;
                _emit();
              },
            ),
          ],
        ),
      ),
    );
  }
}
