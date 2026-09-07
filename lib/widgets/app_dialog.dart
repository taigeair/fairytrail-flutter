import 'package:fairytrail/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Minimal alert / confirm dialogs.
abstract final class AppDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'OK',
    VoidCallback? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _AppAlert(
        title: title,
        message: message,
        actions: [
          _Action(
            label: confirmLabel,
            isPrimary: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm?.call();
            },
          ),
        ],
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _AppAlert(
        title: title,
        message: message,
        actions: [
          _Action(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          _Action(
            label: confirmLabel,
            isPrimary: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Action {
  const _Action({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
}

class _AppAlert extends StatelessWidget {
  const _AppAlert({
    required this.title,
    required this.actions,
    this.message,
  });

  final String title;
  final String? message;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 22),
            if (actions.length == 1)
              _DialogButton(action: actions.first)
            else if (actions.any((a) => a.label.trim().contains(' ')))
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _DialogButton(action: actions[i]),
                  ],
                ],
              )
            else
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _DialogButton(action: actions[i])),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      action.label,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16);

    if (action.isPrimary) {
      return SizedBox(
        height: 46,
        child: FilledButton(
          onPressed: action.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            elevation: 0,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: action.onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: padding,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }
}
