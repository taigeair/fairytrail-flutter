import 'package:fairytrail/api/meetups.dart';
import 'package:fairytrail/api/models/meetup_models.dart';
import 'package:fairytrail/meetups/meetup_analytics.dart';
import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:fairytrail/meetups/meetup_category_art.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:fairytrail/screens/meetups/meetup_category_sheet.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/utils/common.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateMeetupScreen extends StatefulWidget {
  const CreateMeetupScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  static Future<MeetupDto?> open(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) {
    return Navigator.of(context).push<MeetupDto>(
      MaterialPageRoute(
        builder: (_) =>
            CreateMeetupScreen(latitude: latitude, longitude: longitude),
      ),
    );
  }

  @override
  State<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends State<CreateMeetupScreen> {
  final _name = TextEditingController();
  MeetupCategory _category = MeetupCategory.social;
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 2));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  DateTime get _min => DateTime.now();
  DateTime get _max => DateTime.now().add(const Duration(days: 10));

  String get _previewTitle {
    final name = _name.text.trim();
    return name.isEmpty ? 'New meetup' : name;
  }

  Future<void> _pickCategory() async {
    final picked = await showMeetupCategorySheet(context, selected: _category);
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(_min.year, _min.month, _min.day),
      lastDate: DateTime(_max.year, _max.month, _max.day),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.show(context, message: 'Give your meetup a name.');
      return;
    }
    if (_startsAt.isBefore(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ) ||
        _startsAt.isAfter(_max)) {
      AppToast.show(context, message: 'Select a time within the next 10 days');
      return;
    }
    setState(() => _saving = true);
    try {
      final meetup = await createMeetup(
        name: name,
        category: _category.apiValue,
        startsAt: _startsAt,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      trackCreatedMeetup(meetup);
      if (mounted) Navigator.pop(context, meetup);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, message: serverErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = meetupCategoryColor(_category);
    final when = DateFormat.MMMd().add_jm().format(_startsAt);

    return AppScaffold(
      title: 'Create meetup',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // Live header preview (updates with name + category).
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.25
                        : 0.06,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                MeetupCategoryThumbnail(
                  category: _category,
                  size: 64,
                  borderRadius: 12,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        _previewTitle,
                        variant: AppTextVariant.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        _category.label,
                        variant: AppTextVariant.caption,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        when,
                        variant: AppTextVariant.caption,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _name,
            label: 'I want to ...',
            hint: 'grab coffee, play football, sing karaoke',
            textCapitalization: TextCapitalization.none,
            maxLength: 120,
          ),
          const SizedBox(height: 20),
          const AppText('Category', variant: AppTextVariant.label),
          const SizedBox(height: 8),
          AppCard(
            onTap: _pickCategory,
            child: Row(
              children: [
                MeetupCategoryThumbnail(
                  category: _category,
                  size: 36,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    _category.label,
                    variant: AppTextVariant.body,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const AppText('When it starts', variant: AppTextVariant.label),
          const SizedBox(height: 8),
          AppCard(
            onTap: _pickDateTime,
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(child: AppText(when, variant: AppTextVariant.body)),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            'This meetup expires 24 hours after the start time.',
            variant: AppTextVariant.caption,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 12),
          AppText(
            'Pinned to the spot you selected. Visible to everyone nearby.',
            variant: AppTextVariant.caption,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _saving ? 'Creating…' : 'Create meetup',
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
