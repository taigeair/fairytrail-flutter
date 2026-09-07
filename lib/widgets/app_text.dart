import 'package:flutter/material.dart';

enum AppTextVariant {
  display,
  headline,
  title,
  body,
  bodySmall,
  label,
  caption,
}

/// Themed text using the app's text styles.
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.fontSize,
  });

  final String text;
  final AppTextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final FontWeight? fontWeight;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = switch (variant) {
      AppTextVariant.display => theme.displayMedium,
      AppTextVariant.headline => theme.headlineMedium,
      AppTextVariant.title => theme.titleLarge,
      AppTextVariant.body => theme.bodyLarge,
      AppTextVariant.bodySmall => theme.bodyMedium,
      AppTextVariant.label => theme.labelLarge,
      AppTextVariant.caption => theme.bodySmall,
    };

    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
      style: base?.copyWith(
        color: color,
        fontWeight: fontWeight,
        fontSize: fontSize,
      ),
    );
  }
}
