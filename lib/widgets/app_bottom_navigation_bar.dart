import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              size: 22,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          elevation: 0,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: destination.icon,
                selectedIcon: _selectedIcon(
                  destination.selectedIcon ?? destination.icon,
                ),
                label: destination.label,
                tooltip: destination.tooltip,
                enabled: destination.enabled,
              ),
          ],
        ),
      ),
    );
  }

  Widget _selectedIcon(Widget icon) => Container(
    width: 52,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(15),
    ),
    child: icon,
  );
}
