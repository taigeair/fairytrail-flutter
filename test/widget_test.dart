import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/main.dart';
import 'package:fairytrail/remote_config/remote_config_controller.dart';
import 'package:fairytrail/theme/theme_controller.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.instance.init();
  });

  testWidgets('Shows welcome when unauthenticated', (tester) async {
    final auth = AuthController();
    await auth.bootstrap();

    await tester.pumpWidget(
      FairytrailApp(
        themeController: ThemeController(initial: ThemeMode.light),
        authController: auth,
        remoteConfigController: RemoteConfigController(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Find friends and adventure'), findsOneWidget);
  });

  testWidgets('Platform deep link does not crash unauthenticated launch', (
    tester,
  ) async {
    final auth = AuthController();
    await auth.bootstrap();

    await tester.pumpWidget(
      FairytrailApp(
        themeController: ThemeController(initial: ThemeMode.light),
        authController: auth,
        remoteConfigController: RemoteConfigController(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePushRoute(
      'https://spring.fairytrail.app/dl/password-reset/test-token',
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
  });
}
