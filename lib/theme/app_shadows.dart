import 'package:flutter/material.dart';

/// Shared neutral drop shadows — pure black alpha only, never brand-tinted.
abstract final class AppShadows {
  /// Default soft elevation for cards, buttons, floating chrome.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color.fromARGB(10, 0, 0, 0), // 10% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color.fromARGB(4, 0, 0, 0), // 4% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Slightly stronger soft shadow for dark surfaces.
  static const List<BoxShadow> softDark = [
    BoxShadow(
      color: Color.fromARGB(60, 0, 0, 0), // 40% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color.fromARGB(30, 0, 0, 0), // 20% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? softDark : soft;
  }
}
