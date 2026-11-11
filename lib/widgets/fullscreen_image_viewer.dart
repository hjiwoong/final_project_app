import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.heroTag,
    required this.child,
  });

  final Object heroTag;
  final Widget child;

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  static const double _dismissDistance = 110;
  static const double _initialScaleTolerance = 0.01;

  final TransformationController _transformationController =
      TransformationController();
  final Set<int> _activePointers = {};
  late final AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _swipeStart;
  Offset? _doubleTapPosition;
  bool _isAtInitialScale = true;
  bool _dismissTriggered = false;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_applyZoomAnimation);
    _zoomAnimationController.addStatusListener(_onZoomAnimationStatusChanged);
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _applyZoomAnimation() {
    final animation = _zoomAnimation;
    if (animation != null) {
      _transformationController.value = animation.value;
    }
  }

  void _onZoomAnimationStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _updateScaleState();
  }

  void _updateScaleState() {
    final isAtInitialScale =
        _transformationController.value.getMaxScaleOnAxis() <=
        1 + _initialScaleTolerance;
    if (isAtInitialScale == _isAtInitialScale) return;
    setState(() {
      _isAtInitialScale = isAtInitialScale;
      _swipeStart = null;
    });
  }

  void _onInteractionUpdate(ScaleUpdateDetails _) {
    _updateScaleState();
  }

  void _animateTransformation(Matrix4 target) {
    _zoomAnimationController.stop();
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value.clone(),
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _zoomAnimationController.forward(from: 0);
  }

  void _onDoubleTap() {
    final position = _doubleTapPosition;
    if (position == null) return;

    if (_isAtInitialScale) {
      final zoom = Matrix4.identity()
        ..translateByDouble(position.dx, position.dy, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1)
        ..translateByDouble(-position.dx, -position.dy, 0, 1);
      _animateTransformation(zoom);
      setState(() {
        _isAtInitialScale = false;
        _swipeStart = null;
      });
    } else {
      _animateTransformation(Matrix4.identity());
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length == 1 && _isAtInitialScale) {
      _swipeStart = event.position;
    } else {
      _swipeStart = null;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _swipeStart;
    if (start == null ||
        _dismissTriggered ||
        !_isAtInitialScale ||
        !_activePointers.contains(event.pointer)) {
      return;
    }

    final delta = event.position - start;
    if (delta.dy.abs() < _dismissDistance ||
        delta.dy.abs() <= delta.dx.abs() * 1.2) {
      return;
    }

    _dismissTriggered = true;
    Navigator.of(context).maybePop();
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _swipeStart = null;
    if (_activePointers.isEmpty) _dismissTriggered = false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.imageViewerSystemUiOverlayStyle,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,
        bottomNavigationBar: SizedBox(
          height: MediaQuery.paddingOf(context).bottom,
        ),
        body: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: GestureDetector(
                  onDoubleTapDown: (details) {
                    _doubleTapPosition = details.localPosition;
                  },
                  onDoubleTap: _onDoubleTap,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1,
                    maxScale: 4,
                    panEnabled: !_isAtInitialScale,
                    onInteractionUpdate: _onInteractionUpdate,
                    child: Hero(tag: widget.heroTag, child: widget.child),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      tooltip: '뒤로',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
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
