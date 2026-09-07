import 'package:fairytrail/api/marketing_emails.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

class MarketingEmailsScreen extends StatefulWidget {
  const MarketingEmailsScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MarketingEmailsScreen()),
    );
  }

  @override
  State<MarketingEmailsScreen> createState() => _MarketingEmailsScreenState();
}

class _MarketingEmailsScreenState extends State<MarketingEmailsScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _subscribed = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await getMarketingEmails();
      if (!mounted) return;
      setState(() {
        _subscribed = res.subscribed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, message: serverErrorText(e));
    }
  }

  Future<void> _toggle(bool next) async {
    if (_saving) return;
    final previous = _subscribed;
    setState(() {
      _subscribed = next;
      _saving = true;
    });
    try {
      final res = await postMarketingEmails(subscribed: next);
      if (!mounted) return;
      setState(() => _subscribed = res.subscribed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _subscribed = previous);
      AppToast.show(context, message: serverErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Email updates',
      body: _loading
          ? const Center(child: AppLoading())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              'Email updates',
                              variant: AppTextVariant.title,
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'Product updates, contests, and free trips.',
                              variant: AppTextVariant.caption,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _subscribed,
                        onChanged: _saving ? null : _toggle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
