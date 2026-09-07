import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<String?> showKeywordFilterDialog(
  BuildContext context, {
  required String initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _KeywordFilterDialog(initialValue: initialValue),
  );
}

class _KeywordFilterDialog extends StatefulWidget {
  const _KeywordFilterDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_KeywordFilterDialog> createState() => _KeywordFilterDialogState();
}

class _KeywordFilterDialogState extends State<_KeywordFilterDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText(
        'Keyword or interest',
        variant: AppTextVariant.title,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(hintText: 'e.g. hiking, sharks'),
      ),
      actions: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          isExpanded: false,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: 'Save',
          isExpanded: false,
          onPressed: _save,
        ),
      ],
    );
  }
}
