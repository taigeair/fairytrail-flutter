import 'package:fairytrail/widgets/app_safe_area.dart';
import 'package:fairytrail/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';

/// Scaffold with safe area, optional title, and consistent padding.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.showAppBar = true,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    // Ancestor Scaffold(extendBody + bottomNav) zeroes MediaQuery.padding.bottom
    // for its body subtree. AppSafeArea still clears the home indicator, and
    // drops that inset while the keyboard is open so inputs have no white bar.
    final safeBottom = bottomNavigationBar == null && !extendBody;

    return Scaffold(
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: showAppBar && title != null
          ? AppBar(title: Text(title!), leading: leading, actions: actions)
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          const ConnectivityBannerStrip(),
          Expanded(
            child: AppSafeArea(
              top: showAppBar && title != null ? false : true,
              bottom: safeBottom,
              child: padding != null
                  ? Padding(padding: padding!, child: body)
                  : body,
            ),
          ),
        ],
      ),
    );
  }
}
