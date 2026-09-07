import 'package:fairytrail/components/messages/conversation_tile.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/widgets/app_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// http(s) and www. URLs in message text.
final _urlRegex = RegExp(
  r'(?:https?:\/\/|www\.)[^\s<>\[\](){}]+',
  caseSensitive: false,
);

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.createdAt,
    this.senderName,
    this.avatarUrl,
    this.avatarAssetPath,
    this.avatarBlurHash,
    this.onAvatarTap,
    this.onSenderTap,
    this.pending = false,
    this.failed = false,
    this.showTail = true,
    this.showAvatar = true,
  });

  final String text;
  final bool isMine;
  final DateTime createdAt;
  final String? senderName;
  final String? avatarUrl;
  final String? avatarAssetPath;
  final String? avatarBlurHash;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSenderTap;
  final bool pending;
  final bool failed;
  final bool showTail;

  /// When false, reserves space but hides the image (grouped consecutive msgs).
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final mineBg = AppColors.primary;
    final otherBg = isDark ? AppColors.darkSurface : Colors.white;
    final mineFg = Colors.white;
    final otherFg = AppColors.textPrimaryOf(context);
    final linkColor = isMine ? Colors.white : AppColors.primary;
    final timeColor = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textSecondaryOf(context);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(isMine || !showTail ? 12 : 0),
      bottomRight: Radius.circular(!isMine || !showTail ? 12 : 0),
    );

    final bubble = CustomPaint(
      painter: showTail
          ? _BubbleTailPainter(
              color: isMine ? mineBg : otherBg,
              isMine: isMine,
              isDark: isDark,
            )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isMine ? mineBg : otherBg,
          borderRadius: radius,
          border: isMine
              ? null
              : Border.all(color: AppColors.borderOf(context)),
          boxShadow: isMine
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : (isDark ? AppShadows.softDark : AppShadows.soft),
        ),
        padding: EdgeInsets.fromLTRB(
          isMine ? 10 : (showTail ? 12 : 10),
          7,
          isMine ? (showTail ? 12 : 10) : 10,
          5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && senderName != null && senderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 4),
                child: GestureDetector(
                  onTap: onSenderTap,
                  child: AppText(
                    senderName!,
                    variant: AppTextVariant.caption,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            // Text + time side-by-side with a fixed gap (avoids overlap on short msgs).
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _SelectableLinkedText(
                    text: text,
                    color: isMine ? mineFg : otherFg,
                    linkColor: linkColor,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (failed)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.error_outline,
                            size: 13,
                            color: Colors.redAccent,
                          ),
                        )
                      else if (pending)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.4,
                              color: timeColor,
                            ),
                          ),
                        ),
                      Text(
                        formatMessageClock(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1,
                          color: timeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 48,
              right: showTail ? 8 : 12,
              top: 1,
              bottom: 1,
            ),
            child: bubble,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8,
          right: 48,
          top: 1,
          bottom: 1,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: showAvatar
                  ? GestureDetector(
                      onTap: onAvatarTap ?? onSenderTap,
                      child: ChatAvatar(
                        url: avatarUrl,
                        assetPath: avatarAssetPath,
                        blurHash: avatarBlurHash,
                        size: 28,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(width: showTail ? 4 : 6),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                child: bubble,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small WhatsApp-style corner tip on the outer bottom of the bubble group.
class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({
    required this.color,
    required this.isMine,
    required this.isDark,
  });

  final Color color;
  final bool isMine;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isMine) {
      path
        ..moveTo(size.width - 6, size.height - 10)
        ..quadraticBezierTo(
          size.width + 2,
          size.height - 4,
          size.width + 6,
          size.height,
        )
        ..lineTo(size.width - 10, size.height - 2)
        ..close();
    } else {
      path
        ..moveTo(6, size.height - 10)
        ..quadraticBezierTo(-2, size.height - 4, -6, size.height)
        ..lineTo(10, size.height - 2)
        ..close();
    }
    // Soft shadow under the tip.
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
      1.5,
      true,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isMine != isMine ||
        oldDelegate.isDark != isDark;
  }
}

class _SelectableLinkedText extends StatefulWidget {
  const _SelectableLinkedText({
    required this.text,
    required this.color,
    required this.linkColor,
  });

  final String text;
  final Color color;
  final Color linkColor;

  @override
  State<_SelectableLinkedText> createState() => _SelectableLinkedTextState();
}

class _SelectableLinkedTextState extends State<_SelectableLinkedText> {
  final _recognizers = <TapGestureRecognizer>[];
  late TextSpan _rootSpan;

  @override
  void initState() {
    super.initState();
    _rootSpan = _buildRootSpan();
  }

  @override
  void didUpdateWidget(covariant _SelectableLinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.color != widget.color ||
        oldWidget.linkColor != widget.linkColor) {
      _rootSpan = _buildRootSpan();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String raw) async {
    var value = raw.trim();
    while (value.isNotEmpty && '.,;:!?)"\''.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  TextSpan _buildRootSpan() {
    _disposeRecognizers();
    final text = widget.text;
    final children = <InlineSpan>[];
    var start = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
      _recognizers.add(recognizer);
      children.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }
    if (children.isEmpty) {
      children.add(TextSpan(text: text));
    }
    return TextSpan(
      style: TextStyle(
        color: widget.color,
        fontSize: 16,
        height: 1.28,
      ),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(_rootSpan);
  }
}

class ChatDateChip extends StatelessWidget {
  const ChatDateChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface
                : const Color(0xFFE8E8ED),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: AppText(
              label,
              variant: AppTextVariant.caption,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF5E5E66),
            ),
          ),
        ),
      ),
    );
  }
}
