import 'package:fairytrail/api/web_login.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Approve a 6-digit code shown on the Fairytrail website (RN `web-login`).
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WebLoginScreen()),
    );
  }

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  static const _codeLength = 6;

  final _controller = TextEditingController();
  bool _loading = false;
  bool _success = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _controller.text.length == _codeLength && !_loading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _loading = true;
      _success = false;
    });
    try {
      await approveWebLoginCode(_controller.text);
      if (!mounted) return;
      setState(() {
        _success = true;
        _controller.clear();
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textSecondaryOf(context);

    return AppScaffold(
      title: 'Login on desktop',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const AppText(
            'Sign in on the web',
            variant: AppTextVariant.headline,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          AppText(
            'Open the Fairytrail website and choose “Code on phone”. Enter the '
            '6-digit code shown there below to log in on the web.',
            variant: AppTextVariant.body,
            color: muted,
          ),
          const SizedBox(height: 28),
          AppTextField(
            controller: _controller,
            hint: '------',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: _codeLength,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _success = false),
            onSubmitted: (_) => _submit(),
          ),
          if (_success) ...[
            const SizedBox(height: 16),
            AppText(
              'Approved. The web page should be signed in now.',
              variant: AppTextVariant.bodySmall,
              color: const Color(0xFF1B873F),
            ),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: 'Approve sign-in',
            onPressed: _canSubmit ? _submit : null,
            isLoading: _loading,
          ),
        ],
      ),
    );
  }
}
