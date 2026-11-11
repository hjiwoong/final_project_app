import 'package:flutter/material.dart';

class ModalSystemUiObserver extends NavigatorObserver {
  ModalSystemUiObserver._();

  static final instance = ModalSystemUiObserver._();

  final barrierColor = ValueNotifier<Color?>(null);
  final List<Route<dynamic>> _modalRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _addModalRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _removeModalRoute(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _removeModalRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _removeModalRoute(oldRoute);
    if (newRoute != null) _addModalRoute(newRoute);
  }

  void _addModalRoute(Route<dynamic> route) {
    if (route is! ModalRoute<dynamic>) return;
    final color = route.barrierColor;
    if (color == null || color.a == 0) return;

    _modalRoutes.remove(route);
    _modalRoutes.add(route);
    _updateBarrierColor();
  }

  void _removeModalRoute(Route<dynamic> route) {
    if (_modalRoutes.remove(route)) _updateBarrierColor();
  }

  void _updateBarrierColor() {
    final color = _modalRoutes.isEmpty
        ? null
        : (_modalRoutes.last as ModalRoute<dynamic>).barrierColor;
    if (barrierColor.value != color) barrierColor.value = color;
  }
}
