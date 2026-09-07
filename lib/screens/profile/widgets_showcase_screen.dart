import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Dev screen that demos every custom widget.
class WidgetsShowcaseScreen extends StatefulWidget {
  const WidgetsShowcaseScreen({super.key});

  @override
  State<WidgetsShowcaseScreen> createState() => _WidgetsShowcaseScreenState();
}

class _WidgetsShowcaseScreenState extends State<WidgetsShowcaseScreen> {
  final _textController = TextEditingController();
  final _areaController = TextEditingController();
  DateTime? _date;
  bool _loading = false;
  double _progress = 0.35;

  @override
  void dispose() {
    _textController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Widgets',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Section(
            title: 'Typography',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppText('Display', variant: AppTextVariant.display),
                SizedBox(height: 4),
                AppText('Headline', variant: AppTextVariant.headline),
                SizedBox(height: 4),
                AppText('Title', variant: AppTextVariant.title),
                SizedBox(height: 4),
                AppText('Body text', variant: AppTextVariant.body),
                SizedBox(height: 4),
                AppText('Body small', variant: AppTextVariant.bodySmall),
                SizedBox(height: 4),
                AppText('Label', variant: AppTextVariant.label),
                SizedBox(height: 4),
                AppText('Caption', variant: AppTextVariant.caption),
              ],
            ),
          ),
          _Section(
            title: 'Buttons',
            child: Column(
              children: [
                AppButton(
                  label: 'Primary',
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Secondary',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Text button',
                  variant: AppButtonVariant.text,
                  isExpanded: false,
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'With icon',
                  icon: Icons.favorite_outline,
                  onPressed: () {},
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Loading',
                  isLoading: _loading,
                  onPressed: () {
                    setState(() => _loading = true);
                    Future<void>.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _loading = false);
                    });
                  },
                ),
              ],
            ),
          ),
          _Section(
            title: 'Inputs',
            child: Column(
              children: [
                AppTextField(
                  controller: _textController,
                  label: 'Text field',
                  hint: 'Type something…',
                  prefixIcon: const Icon(Icons.search),
                ),
                const SizedBox(height: 16),
                AppTextArea(
                  controller: _areaController,
                  label: 'Text area',
                  hint: 'Write a longer note…',
                ),
                const SizedBox(height: 16),
                AppDatePicker(
                  label: 'Date picker',
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Card',
            child: AppCard(
              onTap: () {},
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      'This is an AppCard. Tap me.',
                      variant: AppTextVariant.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: 'Progress',
            child: Column(
              children: [
                AppProgressBar(value: _progress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '−',
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          setState(() {
                            _progress = (_progress - 0.1).clamp(0.0, 1.0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: '+',
                        onPressed: () {
                          setState(() {
                            _progress = (_progress + 0.1).clamp(0.0, 1.0);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  height: 80,
                  child: AppLoading(message: 'Loading…'),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Cached image',
            child: AppCachedImage(
              url: 'https://picsum.photos/seed/fairytrail/400/200',
              height: 160,
              width: double.infinity,
              borderRadius: 12,
            ),
          ),
          _Section(
            title: 'Toast',
            child: Column(
              children: [
                AppButton(
                  label: 'Show toast',
                  onPressed: () {
                    AppToast.show(context, message: 'Hello from AppToast');
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Toast over bottom sheet',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (sheetContext) {
                        return AppSafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AppText(
                                  'Bottom sheet',
                                  variant: AppTextVariant.title,
                                  fontWeight: FontWeight.w700,
                                ),
                                const SizedBox(height: 8),
                                const AppText(
                                  'Tap below — the toast should appear above this sheet.',
                                  variant: AppTextVariant.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                AppButton(
                                  label: 'Show toast',
                                  onPressed: () {
                                    AppToast.show(
                                      sheetContext,
                                      message: 'Toast above the bottom sheet',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          _Section(
            title: 'Dialogs',
            child: Column(
              children: [
                AppButton(
                  label: 'Show dialog',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    AppDialog.show(
                      context,
                      title: 'Hello',
                      message: 'This is an AppDialog.',
                    );
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Confirm dialog',
                  onPressed: () async {
                    final ok = await AppDialog.confirm(
                      context,
                      title: 'Are you sure?',
                      message: 'This is a confirm dialog.',
                    );
                    if (!context.mounted) return;
                    AppToast.show(
                      context,
                      message: ok ? 'Confirmed' : 'Cancelled',
                    );
                  },
                ),
              ],
            ),
          ),
          const _Section(
            title: 'Empty view',
            child: SizedBox(
              height: 180,
              child: AppEmptyView(
                title: 'Nothing here',
                subtitle: 'Empty state example',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, variant: AppTextVariant.headline),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
