import 'package:fairytrail/api/login_apple.dart' as login_apple_api;
import 'package:fairytrail/api/login_google.dart' as login_google_api;
import 'package:fairytrail/api/models/auth_models.dart';
import 'package:fairytrail/config/auth_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

bool get _isApplePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Wraps Google / Apple SDK sign-in and backend exchange.
class SocialAuthService {
  SocialAuthService._();

  static final SocialAuthService instance = SocialAuthService._();

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: _isApplePlatform ? AuthConfig.iosClientId : null,
      serverClientId: AuthConfig.webClientId,
    );
    _googleInitialized = true;
  }

  Future<LoginSuccessResponse> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google sign-in did not return an identity token');
    }

    return login_google_api.loginGoogle(
      identityToken: idToken,
      credential: {
        'id': account.id,
        'email': account.email,
        'displayName': account.displayName,
        'photoUrl': account.photoUrl,
      },
    );
  }

  Future<LoginSuccessResponse> signInWithApple() async {
    if (!_isApplePlatform) {
      throw UnsupportedError('Apple Sign In is only available on Apple platforms');
    }

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw StateError('Apple Sign In is not available on this device');
    }

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple sign-in did not return an identity token');
    }

    return login_apple_api.loginApple(
      identityToken: identityToken,
      credential: {
        'userIdentifier': credential.userIdentifier,
        'email': credential.email,
        'givenName': credential.givenName,
        'familyName': credential.familyName,
        'authorizationCode': credential.authorizationCode,
        'identityToken': credential.identityToken,
      },
    );
  }
}
