import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark);

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void setDark() => state = ThemeMode.dark;
  void setLight() => state = ThemeMode.light;
}

/// Auto-scroll direction: true = scroll to bottom (newest at bottom),
/// false = scroll to top (newest at top)
enum ScrollDirection { bottom, top }

final scrollDirectionProvider = StateProvider<ScrollDirection>(
  (ref) => ScrollDirection.bottom,
);

/// Sidebar collapsed state
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
