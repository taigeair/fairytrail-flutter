import 'package:confetti/confetti.dart';
import 'package:fairytrail/api/models/trail_book_models.dart';
import 'package:fairytrail/api/trail_book.dart';
import 'package:fairytrail/components/trail_book/trail_book_postcard_card.dart';
import 'package:fairytrail/screens/trail_book/trail_book_nav.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/trail_book/postcard_share.dart';
import 'package:fairytrail/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Full-screen blocker when a postcard arrives (RN `careReceived`).
class PostcardReceivedScreen extends StatefulWidget {
  const PostcardReceivedScreen({
    super.key,
    required this.item,
    this.unreadCount = 0,
  });

  static const routeName = '/postcard-received';

  final TrailBookItemDto item;
  final int unreadCount;

  static Future<void> open(
    BuildContext context, {
    required TrailBookItemDto item,
    int unreadCount = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => PostcardReceivedScreen(
          item: item,
          unreadCount: unreadCount,
        ),
      ),
    );
  }

  @override
  State<PostcardReceivedScreen> createState() => _PostcardReceivedScreenState();
}

class _PostcardReceivedScreenState extends State<PostcardReceivedScreen> {
  late final ConfettiController _confetti;
  final _postcardKey = GlobalKey();
  bool _loading = true;
  bool _sharing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    // Brief blocker flash like RN LoadingScreenMemo (~1s).
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _loading = false);
      _confetti.play();
    });
  }

  @override
  void dispose() {
    markTrailBookRead(widget.item.id).ignore();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing || _saving) return;
    setState(() => _sharing = true);
    try {
      await PostcardShare.shareCapturedPostcard(
        context,
        boundaryKey: _postcardKey,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _save() async {
    if (_sharing || _saving) return;
    setState(() => _saving = true);
    try {
      await PostcardShare.saveCapturedPostcard(
        context,
        boundaryKey: _postcardKey,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = widget.unreadCount > 1 ? widget.unreadCount : 0;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: AppLoading()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          AppSafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 700;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    compactHeight ? 4 : 8,
                    20,
                    compactHeight ? 12 : 20,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: compactHeight ? 48 : 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 52,
                              ),
                              child: const AppText(
                                'You received a postcard!',
                                variant: AppTextVariant.title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compactHeight ? 10 : 18),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compactHeight ? 240 : 280,
                            ),
                            child: AspectRatio(
                              aspectRatio: 0.62,
                              child: RepaintBoundary(
                                key: _postcardKey,
                                child: TrailBookPostcardCard(item: widget.item),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compactHeight ? 10 : 16),
                      if (unread > 0) ...[
                        Text(
                          'You have $unread unread postcards!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        SizedBox(height: compactHeight ? 10 : 16),
                      ],
                      AppButton(
                        label: 'Share',
                        icon: Icons.ios_share_outlined,
                        isLoading: _sharing,
                        onPressed: _saving ? null : _share,
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Save to Photos',
                        icon: Icons.download_outlined,
                        variant: AppButtonVariant.secondary,
                        isLoading: _saving,
                        onPressed: _sharing ? null : _save,
                      ),
                      SizedBox(height: compactHeight ? 2 : 6),
                      AppButton(
                        label: 'View your postcard collection',
                        variant: AppButtonVariant.text,
                        onPressed: () {
                          Navigator.pop(context);
                          openTrailBook(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
            ),
          ),
        ],
      ),
    );
  }
}
