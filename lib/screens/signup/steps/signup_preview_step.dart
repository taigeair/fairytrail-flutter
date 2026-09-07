import 'dart:io';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:fairytrail/auth/auth_controller.dart';
import 'package:fairytrail/config/explore_options.dart';
import 'package:fairytrail/config/signup_options.dart';
import 'package:fairytrail/registration/background_photo_upload.dart';
import 'package:fairytrail/screens/signup/signup_step_scaffold.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 7 — passport-style profile preview with confetti.
class SignupPreviewStep extends StatefulWidget {
  const SignupPreviewStep({
    super.key,
    required this.name,
    required this.profileType,
    required this.age,
    required this.mobility,
    required this.storyTime,
    this.travelKind,
    required this.onContinue,
  });

  final String name;
  final String profileType;
  final int? age;
  final String mobility;
  final String storyTime;
  final String? travelKind;
  final VoidCallback onContinue;

  @override
  State<SignupPreviewStep> createState() => _SignupPreviewStepState();
}

class _SignupPreviewStepState extends State<SignupPreviewStep> {
  late final ConfettiController _confetti;

  /// Snapshotted so a later upload-complete / auth refresh rebuild can't blank it.
  late final String? _photoPath;
  late final DateTime _issuedAt;
  late final int _passNoSuffix;

  @override
  void initState() {
    super.initState();
    _photoPath = BackgroundPhotoUpload.instance.photoPath;
    _issuedAt = DateTime.now();
    _passNoSuffix = math.Random().nextInt(90) + 10;
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _displayName {
    final name = widget.name.trim();
    if (widget.age == null) return name;
    return '$name, ${widget.age}';
  }

  String get _bioLine {
    final story = widget.storyTime.trim();
    if (story.isNotEmpty) {
      if (story.length <= 90) return story;
      return '${story.substring(0, 87).trimRight()}…';
    }
    final type = widget.profileType.isNotEmpty
        ? labelForProfileType(widget.profileType).toLowerCase()
        : 'traveler';
    return 'A traveler ready for exciting adventures.';
  }

  String get _styleLabel {
    final travel = labelForTravelStyle(widget.travelKind);
    if (travel.isNotEmpty) return travel;
    if (widget.mobility == 'remote') return 'Fully Remote';
    if (widget.mobility.isNotEmpty) return labelForMobility(widget.mobility);
    return 'Explorer';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM yyyy').format(_issuedAt).toUpperCase();
    final profileId = AuthScope.of(context).profileMeta?.id;
    final passNoBase = profileId != null && profileId > 0
        ? profileId.toString().padLeft(6, '0')
        : DateFormat('HHmmss').format(_issuedAt);
    final passNo = '$passNoBase$_passNoSuffix';

    return Stack(
      children: [
        SignupStepScaffold(
          step: 7,
          title: 'Profile created 🥳',
          subtitle: 'You’re all set. Let’s finish a couple quick steps.',
          continueLabel: 'Continue',
          onContinue: widget.onContinue,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: _PassportCard(
              photoPath: _photoPath,
              photoUrl: AuthScope.of(context).profileMeta?.photoUrl,
              displayName: _displayName,
              bioLine: _bioLine,
              styleLabel: _styleLabel,
              dateLabel: dateLabel,
              passNo: passNo,
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 28,
            maxBlastForce: 24,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            gravity: 0.25,
            colors: const [
              AppColors.primary,
              Color(0xFFFFC107),
              Color(0xFF4CAF50),
              Color(0xFFE91E63),
            ],
          ),
        ),
      ],
    );
  }
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({
    required this.photoPath,
    this.photoUrl,
    required this.displayName,
    required this.bioLine,
    required this.styleLabel,
    required this.dateLabel,
    required this.passNo,
  });

  final String? photoPath;
  final String? photoUrl;
  final String displayName;
  final String bioLine;
  final String styleLabel;
  final String dateLabel;
  final String passNo;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final cardBg = isDark ? AppColors.darkSurface : AppColors.white;
    final dashed = AppColors.primary.withValues(alpha: isDark ? 0.45 : 0.28);
    final watermark = AppColors.primary.withValues(alpha: 0.06);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.of(context),
      ),
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: dashed,
          radius: 22,
          strokeWidth: 1.4,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 0,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    size: 72,
                    color: watermark,
                  ),
                ),
              ),
              Positioned(
                bottom: 28,
                left: 8,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Text(
                    'VISA',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: watermark,
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon(
                      //   Icons.public,
                      //   size: 16,
                      //   color: AppColors.primary.withValues(alpha: 0.7),
                      // ),
                      Icon(
                        Icons.luggage_outlined,
                        size: 16,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FAIRYTRAIL',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.2,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _PassportPhoto(photoPath: photoPath, photoUrl: photoUrl),
                  const SizedBox(height: 16),
                  AppText(
                    displayName,
                    variant: AppTextVariant.headline,
                    fontWeight: FontWeight.w800,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _ApprovedStamp(dateLabel: dateLabel),
                  const SizedBox(height: 14),
                  AppText(
                    bioLine,
                    variant: AppTextVariant.bodySmall,
                    textAlign: TextAlign.center,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    styleLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 18),
                  CustomPaint(
                    painter: _DashedLinePainter(
                      color: AppColors.borderOf(context),
                    ),
                    child: const SizedBox(width: double.infinity, height: 1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          'Passport No. A$passNo',
                          // '@fairytrailapp',
                          // 'ISSUED: $dateLabel',
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 11,
                        ),
                      ),
                      AppText(
                        '@fairytrailapp',
                        // 'Passport No. A$passNo',
                        variant: AppTextVariant.caption,
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportPhoto extends StatelessWidget {
  const _PassportPhoto({this.photoPath, this.photoUrl});

  final String? photoPath;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 132.0;
    final hasLocal = photoPath != null && photoPath!.isNotEmpty;
    final hasRemote = photoUrl != null && photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: hasLocal
            ? Image.file(
                File(photoPath!),
                fit: BoxFit.cover,
                width: size,
                height: size,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => hasRemote
                    ? AppCachedImage(url: photoUrl!)
                    : _photoPlaceholder(context),
              )
            : hasRemote
                ? AppCachedImage(url: photoUrl!)
                : _photoPlaceholder(context),
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    return ColoredBox(
      color: AppColors.chipTagBgOf(context),
      child: Icon(
        Icons.person,
        size: 56,
        color: AppColors.textSecondaryOf(context),
      ),
    );
  }
}

class _ApprovedStamp extends StatelessWidget {
  const _ApprovedStamp({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.85),
            width: 2.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              'ADMITTED',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.4,
                color: AppColors.primary.withValues(alpha: 0.9),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.primary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
