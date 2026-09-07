import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

Future<MeetupCategory?> showMeetupCategorySheet(
  BuildContext context, {
  MeetupCategory? selected,
}) {
  return showModalBottomSheet<MeetupCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MeetupCategorySheet(selected: selected),
  );
}

class _MeetupCategorySheet extends StatelessWidget {
  const _MeetupCategorySheet({this.selected});

  final MeetupCategory? selected;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.62;

    return AppSafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                'Category',
                variant: AppTextVariant.title,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: MeetupCategory.values.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 56,
                endIndent: 12,
                color: AppColors.borderOf(context).withValues(alpha: 0.35),
              ),
              itemBuilder: (context, index) {
                final category = MeetupCategory.values[index];
                return _CategoryRow(
                  category: category,
                  selected: category == selected,
                  onTap: () => Navigator.pop(context, category),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final MeetupCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: selected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Text(
        meetupCategoryEmoji(category),
        style: const TextStyle(fontSize: 22, height: 1),
      ),
      title: AppText(
        category.label,
        variant: AppTextVariant.label,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, size: 22, color: AppColors.primary)
          : null,
    );
  }
}
