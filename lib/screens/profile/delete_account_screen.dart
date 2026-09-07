import 'package:fairytrail/api/account.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/screens/profile/account_pause_confirm_screen.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()),
    );
  }

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _reasonController = TextEditingController();
  bool _understoodData = false;
  bool _understoodPurchases = false;
  bool _loading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _reasonController.text.trim().length > 3 &&
      _understoodData &&
      _understoodPurchases;

  Future<void> _emailSupport() async {
    final uri = Uri.parse('mailto:team@fairytrail.app');
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        AppToast.show(context, message: 'Could not open email app');
      }
    } catch (e) {
      debugPrint('[DeleteAccount] mailto failed: $e');
      if (mounted) {
        AppToast.show(context, message: 'Could not open email app');
      }
    }
  }

  Future<void> _delete() async {
    if (!_canDelete || _loading) return;
    setState(() => _loading = true);
    try {
      await deleteAccount(reason: _reasonController.text.trim());
      if (!mounted) return;
      // API sets accountStatus=pending_deletion + clears tokens.
      // Show goodbye (30-day grace) then welcome — RN delete-goodbye.
      await AuthScope.of(context).enterDeleteGoodbye();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: serverErrorText(e));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Delete account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          AppText(
            'We are so sorry Fairytrail did not meet your needs. If cost is an issue, ask us about our open remote jobs or financial aid program.',
            variant: AppTextVariant.body,
            textAlign: TextAlign.center,
            color: AppColors.textPrimaryOf(context),
          ),
          const SizedBox(height: 24),
          AppTextArea(
            controller: _reasonController,
            label: 'Please share feedback so we can improve',
            hint: '',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _understoodData,
            onChanged: (v) => setState(() => _understoodData = v ?? false),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: AppText(
              'I understand deleting my account will permanently erase all my data and trail money, and this action cannot be undone.',
              variant: AppTextVariant.bodySmall,
            ),
          ),
          CheckboxListTile(
            value: _understoodPurchases,
            onChanged: (v) => setState(() => _understoodPurchases = v ?? false),
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: AppText(
              'I understand consumable purchases such as verification cannot be recovered and will need to be re-purchased if I sign up again.',
              variant: AppTextVariant.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Delete account',
            isLoading: _loading,
            onPressed: _canDelete ? _delete : null,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Pause instead',
            variant: AppButtonVariant.text,
            onPressed: () => AccountPauseConfirmScreen.open(context),
          ),
          const SizedBox(height: 16),
          // GestureDetector is more reliable than TextSpan recognizers inside
          // a scrolling ListView.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _emailSupport,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: const [
                    TextSpan(text: 'Want to chat? Email us at '),
                    TextSpan(
                      text: 'team@fairytrail.app',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.blue,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
