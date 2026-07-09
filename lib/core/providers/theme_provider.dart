import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Default to light theme per user request. The user can still switch to
// dark (or follow system) from Settings → Appearance at any time; the
// choice persists for the session via this StateProvider.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
