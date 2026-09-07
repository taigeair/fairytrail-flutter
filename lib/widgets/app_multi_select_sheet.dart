import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/app_button.dart';
import 'package:fairytrail/widgets/app_safe_area.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:fairytrail/widgets/app_text_field.dart';
import 'package:fairytrail/widgets/app_toast.dart';
import 'package:flutter/material.dart';

/// One row in [AppMultiSelectSheet].
class AppMultiSelectItem<T> {
  const AppMultiSelectItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// Shared multi-select bottom sheet with optional search.
///
/// On open, checked items are sorted to the top. Toggling selection does not
/// reorder the list.
abstract final class AppMultiSelectSheet {
  static Future<List<T>?> show<T>(
    BuildContext context, {
    required String title,
    required List<AppMultiSelectItem<T>> items,
    required List<T> selected,
    bool searchable = false,
    int? limit,
    bool disallowEmpty = false,
    double? heightFactor,
    String searchHint = 'Search',
  }) {
    return showModalBottomSheet<List<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AppMultiSelectSheetBody<T>(
        title: title,
        items: items,
        initialSelected: selected,
        searchable: searchable,
        limit: limit,
        disallowEmpty: disallowEmpty,
        heightFactor: heightFactor ?? (searchable ? 0.7 : 0.55),
        searchHint: searchHint,
      ),
    );
  }
}

class _AppMultiSelectSheetBody<T> extends StatefulWidget {
  const _AppMultiSelectSheetBody({
    required this.title,
    required this.items,
    required this.initialSelected,
    required this.searchable,
    required this.limit,
    required this.disallowEmpty,
    required this.heightFactor,
    required this.searchHint,
  });

  final String title;
  final List<AppMultiSelectItem<T>> items;
  final List<T> initialSelected;
  final bool searchable;
  final int? limit;
  final bool disallowEmpty;
  final double heightFactor;
  final String searchHint;

  @override
  State<_AppMultiSelectSheetBody<T>> createState() =>
      _AppMultiSelectSheetBodyState<T>();
}

class _AppMultiSelectSheetBodyState<T> extends State<_AppMultiSelectSheetBody<T>> {
  late List<T> _current = List<T>.from(widget.initialSelected);
  late final List<AppMultiSelectItem<T>> _ordered = selectedFirst(
    widget.items,
    (e) => widget.initialSelected.contains(e.value),
  );
  String _query = '';

  List<AppMultiSelectItem<T>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _ordered;
    return [
      for (final e in _ordered)
        if (e.label.toLowerCase().contains(q)) e,
    ];
  }

  void _reset() {
    setState(() {
      _current = widget.disallowEmpty
          ? [for (final item in widget.items) item.value]
          : <T>[];
    });
  }

  void _toggle(AppMultiSelectItem<T> item, bool? selected) {
    setState(() {
      if (selected == true) {
        final limit = widget.limit;
        if (limit != null &&
            _current.length >= limit &&
            !_current.contains(item.value)) {
          AppToast.show(context, message: 'Limit is $limit');
          return;
        }
        if (!_current.contains(item.value)) {
          _current = [..._current, item.value];
        }
        return;
      }

      final next = List<T>.from(_current)..remove(item.value);
      if (widget.disallowEmpty && next.isEmpty) return;
      _current = next;
    });
  }

  void _done() {
    if (widget.disallowEmpty && _current.isEmpty) return;
    Navigator.pop(context, _current);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return AppSafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * widget.heightFactor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      widget.title,
                      variant: AppTextVariant.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppButton(
                    label: 'Reset',
                    variant: AppButtonVariant.text,
                    isExpanded: false,
                    onPressed: _reset,
                  ),
                  AppButton(
                    label: 'Done',
                    variant: AppButtonVariant.text,
                    isExpanded: false,
                    onPressed: _done,
                  ),
                ],
              ),
            ),
            if (widget.searchable) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppTextField(
                  hint: widget.searchHint,
                  maxLength: 20,
                  prefixIcon: const Icon(Icons.search),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final item = visible[i];
                  final checked = _current.contains(item.value);
                  return CheckboxListTile(
                    value: checked,
                    activeColor: AppColors.primary,
                    title: AppText(item.label),
                    onChanged: (sel) => _toggle(item, sel),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
