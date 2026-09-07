import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/auth/login_screen.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Step 1: collect email and fork to login vs registration.
class AskForEmailScreen extends StatefulWidget {
  const AskForEmailScreen({
    super.key,
    this.showWelcomeBackButton = false,
    this.prefillStoredEmail = false,
  });

  final bool showWelcomeBackButton;
  final bool prefillStoredEmail;

  @override
  State<AskForEmailScreen> createState() => _AskForEmailScreenState();
}

class _AskForEmailScreenState extends State<AskForEmailScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefillStoredEmail) {
      _prefillEmail();
    }
  }

  Future<void> _prefillEmail() async {
    final email = await LocalStorage.instance.getEmail();
    if (!mounted || email == null || _emailController.text.isNotEmpty) return;
    _emailController.text = email;
    _emailController.selection = TextSelection.collapsed(offset: email.length);
  }

  Future<void> _onContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppToast.show(context, message: 'Please enter a valid email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthScope.of(context).startEmailSignup(email);
      if (!mounted) return;

      if (result.isEmailExists) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
      }
      // New email: draft token is set → AuthGate shows SignupFlowScreen.
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.showWelcomeBackButton,
        leading: widget.showWelcomeBackButton
            ? IconButton(
                onPressed: () => AuthScope.of(context).cancelEmailSignup(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                tooltip: 'Back',
              )
            : null,
        actions: const [],
      ),
      body: AppSafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 416),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppText(
                    "What's your email?",
                    variant: AppTextVariant.headline,
                    fontWeight: FontWeight.w700,
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    controller: _emailController,
                    hint: 'Tap here to type',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onContinue(),
                    autofocus: true,
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Continue',
                    isLoading: _isLoading,
                    onPressed: _onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
