import 'dart:math' as math;

import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:flutter/material.dart';

/// Category thumbnail — matches colorful map pin style.
class MeetupCategoryThumbnail extends StatelessWidget {
  const MeetupCategoryThumbnail({
    super.key,
    required this.category,
    this.size = 72,
    this.borderRadius = 14,
    this.showBorder = true,
    this.emojiScale = 0.42,
  });

  final MeetupCategory category;
  final double size;
  final double borderRadius;
  final bool showBorder;
  final double emojiScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: const Color(0xFFE8E8E8)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        meetupCategoryEmoji(category),
        style: TextStyle(fontSize: size * emojiScale, height: 1),
      ),
    );
  }
}

/// Circle head map pin layout.
typedef MeetupStemPinLayout = ({Offset headCenter, double headRadius});

MeetupStemPinLayout meetupStemPinLayout({
  required double pad,
  required double contentW,
  required double contentH,
}) {
  final cx = pad + contentW / 2;
  final cy = pad + contentH / 2;
  final headRadius = (contentW < contentH ? contentW : contentH) * 0.48;

  return (headCenter: Offset(cx, cy), headRadius: headRadius);
}

/// Badge-on-stem map pin layout (rounded square + stem + anchor dot).
typedef MeetupBadgePinLayout = ({
  double cx,
  Rect badgeRect,
  double badgeRadius,
  Offset stemTop,
  Offset stemBottom,
  double stemWidth,
  Offset dotCenter,
  double dotRadius,
});

MeetupBadgePinLayout meetupBadgePinLayout({
  required double pad,
  required double contentW,
  required double contentH,
}) {
  final cx = pad + contentW / 2;
  final badgeSize = contentW * 0.84;
  final badgeLeft = cx - badgeSize / 2;
  final badgeTop = pad + contentH * 0.02;
  final badgeRect = Rect.fromLTWH(badgeLeft, badgeTop, badgeSize, badgeSize);
  final badgeRadius = badgeSize * 0.24;
  final dotRadius = badgeSize * 0.12;
  final dotCenter = Offset(cx, pad + contentH - dotRadius - 0.5);
  final stemWidth = badgeSize * 0.1;
  final stemTop = Offset(cx, badgeRect.bottom);
  final stemBottom = Offset(cx, dotCenter.dy - dotRadius);

  return (
    cx: cx,
    badgeRect: badgeRect,
    badgeRadius: badgeRadius,
    stemTop: stemTop,
    stemBottom: stemBottom,
    stemWidth: stemWidth,
    dotCenter: dotCenter,
    dotRadius: dotRadius,
  );
}

Path meetupBadgePinShadowPath(MeetupBadgePinLayout layout) {
  final badge = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        layout.badgeRect,
        Radius.circular(layout.badgeRadius),
      ),
    );
  final stem = Path()
    ..addRect(
      Rect.fromCenter(
        center: Offset(
          layout.cx,
          (layout.stemTop.dy + layout.stemBottom.dy) / 2,
        ),
        width: layout.stemWidth,
        height: (layout.stemBottom.dy - layout.stemTop.dy).abs(),
      ),
    );
  final dot = Path()
    ..addOval(
      Rect.fromCircle(center: layout.dotCenter, radius: layout.dotRadius),
    );
  return Path.combine(
    PathOperation.union,
    Path.combine(PathOperation.union, badge, stem),
    dot,
  );
}

/// Round map pin: circle head + short triangular pointer.
Path meetupCirclePinPath(double width, double height) {
  final r = width * 0.40;
  final cx = width / 2;
  final cy = r + 2;
  final tipY = height - 1;
  return meetupCirclePinPathAt(cx: cx, cy: cy, r: r, tipY: tipY);
}

Path meetupCirclePinPathAt({
  required double cx,
  required double cy,
  required double r,
  required double tipY,
}) {
  // Pointer attaches ~35° off the bottom so the tip reads clean and short.
  const attachDeg = 38.0;
  final attachRad = attachDeg * math.pi / 180;
  final left = Offset(
    cx - r * math.sin(attachRad),
    cy + r * math.cos(attachRad),
  );
  final right = Offset(
    cx + r * math.sin(attachRad),
    cy + r * math.cos(attachRad),
  );

  return Path()
    ..moveTo(cx, tipY)
    ..lineTo(left.dx, left.dy)
    ..arcToPoint(
      right,
      radius: Radius.circular(r),
      largeArc: true,
      clockwise: true,
    )
    ..lineTo(cx, tipY)
    ..close();
}

/// Legacy alias.
Path meetupTeardropPath(double width, double height) =>
    meetupCirclePinPath(width, height);
