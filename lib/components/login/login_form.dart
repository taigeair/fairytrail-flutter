import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Minimal email + password form for the login screen.
class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onSubmit,
    required this.onForgotPassword,
    this.errorText,
    this.isLoading = false,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final String? errorText;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppText(
          'Login to your account',
          variant: AppTextVariant.headline,
          textAlign: TextAlign.center,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(height: 8),
        AppText(
          'Welcome back — enter your details to continue',
          variant: AppTextVariant.bodySmall,
          textAlign: TextAlign.center,
          color: muted,
        ),
        const SizedBox(height: 28),
        if (errorText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppText(
              errorText!,
              variant: AppTextVariant.bodySmall,
              color: AppColors.primary,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        AppTextField(
          controller: emailController,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: passwordController,
          hint: 'Password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: AppButton(
            label: 'Forgot Password?',
            variant: AppButtonVariant.text,
            isExpanded: false,
            onPressed: isLoading ? null : onForgotPassword,
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Continue',
          isLoading: isLoading,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}
