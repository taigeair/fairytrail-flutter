import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Shown when connect returns a mutual match (RN `ConnectedWithScreen`).
class ConnectedScreen extends StatelessWidget {
  const ConnectedScreen({
    super.key,
    required this.profileName,
    required this.onSendMessage,
    required this.onLater,
  });

  final String profileName;
  final VoidCallback onSendMessage;
  final VoidCallback onLater;

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
                      AppText(
                        "You've connected with $profileName!",
                        variant: AppTextVariant.title,
                        textAlign: TextAlign.center,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                      const SizedBox(height: 12),
                      AppText(
                        'Talk travel, grab a coffee, or plan adventures together',
                        variant: AppTextVariant.body,
                        textAlign: TextAlign.center,
                        fontSize: 18,
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: 'Send message',
                onPressed: onSendMessage,
              ),
              const SizedBox(height: 4),
              AppButton(
                label: 'Later',
                variant: AppButtonVariant.text,
                onPressed: onLater,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
