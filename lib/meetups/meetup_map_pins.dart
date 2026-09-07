import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fairytrail/meetups/meetup_category.dart';
import 'package:fairytrail/meetups/meetup_category_art.dart';
import 'package:fairytrail/meetups/meetup_icons.dart';
import 'package:flutter/material.dart';

/// Circle head map pin (logical px). iOS uses full size; Android scales down
/// in [MeetupsMapView] because Google Maps draws bitmaps larger.
const meetupPinLogicalWidth = 48.0;
const meetupPinLogicalHeight = 48.0;

Future<Uint8List> meetupCategoryPinPng(
  MeetupCategory category, {
  double logicalWidth = meetupPinLogicalWidth,
  double logicalHeight = meetupPinLogicalHeight,
  double pixelRatio = 3,
}) async {
  return _paintPin(
    emoji: meetupCategoryEmoji(category),
    accent: meetupCategoryColor(category),
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    pixelRatio: pixelRatio,
  );
}

Future<Uint8List> meetupDraftPinPng({
  double logicalWidth = meetupPinLogicalWidth,
  double logicalHeight = meetupPinLogicalHeight,
  double pixelRatio = 3,
}) async {
  const accent = Color(0xFF7B61FF);
  final w = logicalWidth * pixelRatio;
  final h = logicalHeight * pixelRatio;
  // Extra pad so the thick outer halo isn’t clipped.
  final pad = 7 * pixelRatio;
  final contentW = w - pad * 2;
  final contentH = h - pad * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final layout = meetupStemPinLayout(
    pad: pad,
    contentW: contentW,
    contentH: contentH,
  );

  _paintCircleHead(canvas, layout: layout, accent: accent, pixelRatio: pixelRatio);

  _paintMaterialIcon(
    canvas,
    center: layout.headCenter,
    icon: Icons.add_rounded,
    color: accent,
    size: layout.headRadius * 1.15,
  );

  return _encodeCanvas(recorder, w, h);
}

Future<Uint8List> meetupUserLocationDotPng({
  double logicalSize = 16,
  double pixelRatio = 3,
}) async {
  final w = logicalSize * pixelRatio;
  final h = logicalSize * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(w / 2, h / 2);
  final dotRadius = (logicalSize / 2 - 2.5) * pixelRatio;

  // White ring — readable on any map tile.
  canvas.drawCircle(
    center,
    dotRadius + 2.2 * pixelRatio,
    Paint()
      ..color = Colors.white
      ..isAntiAlias = true,
  );

  // Google Maps–style blue dot, without the accuracy circle.
  canvas.drawCircle(
    center,
    dotRadius,
    Paint()
      ..color = const Color(0xFF4285F4)
      ..isAntiAlias = true,
  );

  return _encodeCanvas(recorder, w, h);
}

Future<Uint8List> _paintPin({
  required String emoji,
  required Color accent,
  required double logicalWidth,
  required double logicalHeight,
  required double pixelRatio,
}) async {
  final w = logicalWidth * pixelRatio;
  final h = logicalHeight * pixelRatio;
  // Extra pad so the thick outer halo isn’t clipped.
  final pad = 7 * pixelRatio;
  final contentW = w - pad * 2;
  final contentH = h - pad * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final layout = meetupStemPinLayout(
    pad: pad,
    contentW: contentW,
    contentH: contentH,
  );

  _paintCircleHead(canvas, layout: layout, accent: accent, pixelRatio: pixelRatio);

  _paintEmoji(
    canvas,
    center: layout.headCenter,
    emoji: emoji,
    fontSize: layout.headRadius * 1.2,
  );

  return _encodeCanvas(recorder, w, h);
}

void _paintCircleHead(
  Canvas canvas, {
  required MeetupStemPinLayout layout,
  required Color accent,
  required double pixelRatio,
}) {
  // Soft drop shadow (kept tight so the pin itself stays sharp).
  canvas.drawCircle(
    layout.headCenter + Offset(0, 1.5 * pixelRatio),
    layout.headRadius * 0.92,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pixelRatio)
      ..isAntiAlias = true,
  );

  // White halo — keeps the pin visible on dark / satellite maps.
  canvas.drawCircle(
    layout.headCenter,
    layout.headRadius,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5 * pixelRatio
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true,
  );

  // Solid white fill
  canvas.drawCircle(
    layout.headCenter,
    layout.headRadius,
    Paint()
      ..color = Colors.white
      ..isAntiAlias = true,
  );

  // Bold category border (full opacity — noticeability on both platforms).
  canvas.drawCircle(
    layout.headCenter,
    layout.headRadius - 0.5 * pixelRatio,
    Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4 * pixelRatio
      ..isAntiAlias = true,
  );
}

Future<Uint8List> _encodeCanvas(
  ui.PictureRecorder recorder,
  double w,
  double h,
) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.ceil(), h.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void _paintEmoji(
  Canvas canvas, {
  required Offset center,
  required String emoji,
  required double fontSize,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: emoji,
      style: TextStyle(
        fontSize: fontSize,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}

void _paintMaterialIcon(
  Canvas canvas, {
  required Offset center,
  required IconData icon,
  required Color color,
  required double size,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}
