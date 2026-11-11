import 'dart:async';

import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class InAppNotificationBanner {
  InAppNotificationBanner._();

  static OverlayEntry? _entry;

  static void showMessage(
    String message, {
    String title = '',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (message.trim().isEmpty) return;
    show(
      title: title,
      body: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void show({
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _BannerCard(
                  title: title,
                  body: body,
                  actionLabel: actionLabel,
                  onAction: onAction,
                  onDismiss: () {
                    if (identical(_entry, entry)) {
                      _entry?.remove();
                      _entry = null;
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _BannerCard extends StatefulWidget {
  const _BannerCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> {
  static const _dismissDistance = 36.0;
  static const _maxDownwardDrag = 72.0;

  Timer? _timer;
  double _dragOffset = 0;
  bool _visible = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _dismiss);
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resumeTimer() {
    if (!_isDismissing) _startTimer();
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _timer?.cancel();
    setState(() => _visible = false);
    Future<void>.delayed(const Duration(milliseconds: 220), widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final background = isDark
        ? const Color(0xFF202124)
        : theme.colorScheme.surface;

    return Semantics(
      liveRegion: true,
      label: widget.body,
      child: Listener(
        onPointerDown: (_) => _pauseTimer(),
        onPointerUp: (_) => _resumeTimer(),
        onPointerCancel: (_) => _resumeTimer(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dy).clamp(
                -double.infinity,
                _maxDownwardDrag,
              );
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset < -_dismissDistance ||
                (details.primaryVelocity ?? 0) < -250) {
              _dismiss();
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: _visible ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _visible ? 1 : 0,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Material(
                  color: background,
                  elevation: isDark ? 10 : 8,
                  shadowColor: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.notifications_rounded,
                            color: accent,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.body.isNotEmpty) ...[
                                Text(
                                  widget.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null)
                          TextButton(
                            onPressed: () {
                              widget.onAction!.call();
                              _dismiss();
                            },
                            child: Text(widget.actionLabel!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
