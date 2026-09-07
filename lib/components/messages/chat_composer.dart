import 'package:fairytrail/haptics/haptics_service.dart';
import 'package:fairytrail/theme/app_colors.dart';
import 'package:fairytrail/theme/app_shadows.dart';
import 'package:fairytrail/utils/storage/local_storage.dart';
import 'package:flutter/material.dart';

/// Avoids Flutter [TextSelectionOverlay] RangeErrors when selection handles
/// drag past the text (common with Arabic / RTL + IME).
class _SafeTextEditingController extends TextEditingController {
  @override
  set value(TextEditingValue newValue) {
    final text = newValue.text;
    final max = text.length;
    var selection = newValue.selection;
    if (!selection.isValid ||
        selection.start < 0 ||
        selection.end < 0 ||
        selection.start > max ||
        selection.end > max) {
      final offset = selection.isValid
          ? selection.extentOffset.clamp(0, max)
          : max;
      selection = TextSelection.collapsed(offset: offset);
    }
    var composing = newValue.composing;
    if (composing.isValid &&
        (composing.start < 0 ||
            composing.end < 0 ||
            composing.start > max ||
            composing.end > max)) {
      composing = TextRange.empty;
    }
    super.value = newValue.copyWith(selection: selection, composing: composing);
  }
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.enabled = true,

    /// Persists typed text until send or manual clear (RN draft_message_*).
    this.draftKey,
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final String? draftKey;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with WidgetsBindingObserver {
  final _controller = _SafeTextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;
  bool _wantsFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_onFocusChange);
    _loadDraft();
  }

  @override
  void didChangeMetrics() {
    // Android can dismiss the keyboard while focus remains; rebuild so bottom
    // safe-area padding is restored from real view insets.
    if (mounted) setState(() {});
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draftKey != widget.draftKey) {
      _loadDraft();
    }
    if (!oldWidget.enabled && widget.enabled) {
      _restoreFocus();
    }
  }

  Future<void> _loadDraft() async {
    final key = widget.draftKey;
    if (key == null) return;
    final draft = await LocalStorage.instance.getDraftMessage(key);
    if (!mounted || draft == null || draft.isEmpty) return;
    _controller.text = draft;
    _controller.selection = TextSelection.collapsed(offset: draft.length);
    setState(() => _hasText = draft.trim().isNotEmpty);
  }

  Future<void> _persistDraft(String text) async {
    final key = widget.draftKey;
    if (key == null) return;
    await LocalStorage.instance.setDraftMessage(key, text);
  }

  Future<void> _clearDraft() async {
    final key = widget.draftKey;
    if (key == null) return;
    await LocalStorage.instance.deleteDraftMessage(key);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _restoreFocus() {
    if (!mounted || !widget.enabled || !_wantsFocus) return;
    _focus.requestFocus();
    _wantsFocus = false;
  }

  void _submit() {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticsService.light();
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
    // Sent = cleared; drop the saved draft.
    _clearDraft();
    // Send button tap steals focus; re-open keyboard for the next message.
    _wantsFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFocus());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    // Scaffold zeroes MediaQuery.viewInsets in the body — read the view's
    // raw metrics instead. Don't use focus: Android often closes the keyboard
    // while the field stays focused, which left the composer under the nav bar.
    final viewMq = MediaQueryData.fromView(View.of(context));
    final keyboardOpen = viewMq.viewInsets.bottom > 0;
    final bottomInset = keyboardOpen ? 0.0 : viewMq.viewPadding.bottom;
    final barBg = isDark ? AppColors.darkBackground : Colors.white;
    final fieldBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = AppColors.borderOf(context);
    final radius = BorderRadius.circular(24);

    return Material(
      color: barBg,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          8,
          8,
          8,
          keyboardOpen ? 6 : 8 + bottomInset,
        ),
        child: TextFieldTapRegion(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: radius,
                    border: Border.all(color: borderColor),
                    boxShadow: isDark ? null : AppShadows.soft,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    keyboardAppearance: Theme.of(context).brightness,
                    onTapOutside: (_) => _focus.unfocus(),
                    onChanged: (v) {
                      final has = v.trim().isNotEmpty;
                      if (has != _hasText) setState(() => _hasText = has);
                      // Persist as typed; empty text removes the draft.
                      _persistDraft(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: radius,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: radius,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: radius,
                        borderSide: BorderSide.none,
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: radius,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: AnimatedOpacity(
                  opacity: widget.enabled && _hasText ? 1 : 0.45,
                  duration: const Duration(milliseconds: 150),
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.enabled && _hasText ? _submit : null,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
