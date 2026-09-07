import 'dart:async';

import 'package:fairytrail/analytics/analytics_service.dart';
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/auth/account_restored.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/components/login/social_login_buttons.dart';
import 'package:fairytrail/screens/auth/ask_for_email_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

/// Classic Fairytrail welcome: white hero + red gradient sign-in panel.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    unawaited(AnalyticsService.instance.logEvent('viewed_welcome_screen'));
    // Disabled: Android first-time push permission on welcome.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   unawaited(PushService.instance.requestWelcomeNotificationPermission());
    // });
  }

  Future<void> _runSocial(
    Future<LoginSuccessResponse> Function() action,
  ) async {
    setState(() => _isLoading = true);

    try {
      await action();
      // AuthScope notifies → MainShell shows account-restored alert if needed.
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      AppToast.show(context, message: loginErrorText(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) return;
      AppToast.show(context, message: loginErrorText(e));
    } catch (e) {
      if (!mounted) return;
      final message = loginErrorText(e);
      AppToast.show(context, message: message);
      debugPrint(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onGoogle() {
    unawaited(AnalyticsService.instance.logEvent('started_signup'));
    _runSocial(() => AuthScope.of(context).loginWithGoogle());
  }

  void _onApple() {
    unawaited(AnalyticsService.instance.logEvent('started_signup'));
    _runSocial(() => AuthScope.of(context).loginWithApple());
  }

  void _onEmail() {
    unawaited(AnalyticsService.instance.logEvent('started_signup'));
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AskForEmailScreen()));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: AppLoading(message: 'Signing in…'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: AppSafeArea(
              bottom: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                  child: const WelcomeHero(),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: ClipPath(
              clipper: const _DiagonalClipper(),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(color: AppColors.primary),
                child: AppSafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      32,
                      56,
                      32,
                      20 + bottomPad * 0.25,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    SocialLoginButtons(
                                      onGooglePressed: _onGoogle,
                                      onApplePressed: _onApple,
                                      onEmailPressed: _onEmail,
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: () => _openUrl(
                                        'mailto:team@fairytrail.app',
                                      ),
                                      child: const Text(
                                        'Issues? Email us',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                _AgreementText(
                                  onTerms: () => _openUrl(
                                    'https://www.fairytrail.app/terms.html',
                                  ),
                                  onPrivacy: () => _openUrl(
                                    'https://www.fairytrail.app/terms.html#privacy',
                                  ),
                                  onCookies: () => _openUrl(
                                    'https://www.fairytrail.app/terms.html#cookies',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 28)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _AgreementText extends StatelessWidget {
  const _AgreementText({
    required this.onTerms,
    required this.onPrivacy,
    required this.onCookies,
  });

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onCookies;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.white.withValues(alpha: 0.95),
      fontSize: 14,
      height: 1.45,
    );
    final linkStyle = style.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: AppColors.white,
      fontWeight: FontWeight.w600,
    );

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: "By tapping 'Sign in', you agree to our "),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onTerms,
              child: Text('Terms', style: linkStyle),
            ),
          ),
          const TextSpan(text: '. Learn how we process your data in our '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onPrivacy,
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onCookies,
              child: Text('Cookies Policy', style: linkStyle),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
