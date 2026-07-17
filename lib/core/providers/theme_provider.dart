import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Default to light theme per user request. The user can still switch to
// dark (or follow system) from Settings → Appearance at any time; the
// choice is persisted to SharedPreferences and re-hydrated at boot so it
// survives cold restarts (previously lost on every launch).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// Bilingual EN + HI app. The user's language choice is persisted across
// cold restarts; defaults to English. Hydrated from SharedPreferences in
// `hydratePersistedAppState` (app_state_provider.dart).
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

const _kPrefThemeMode = 'app.themeMode';
const _kPrefLocale = 'app.localeCode';

/// Persist the current theme mode so it survives cold restarts. Values
/// stored as the `ThemeMode.name` (system/light/dark).
Future<void> persistThemeMode(ThemeMode mode) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kPrefThemeMode, mode.name);
}

/// Persist the current locale code ('en' / 'hi') so the Hindi preference
/// survives cold restarts — critical for this bilingual audience.
Future<void> persistLocaleCode(String code) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kPrefLocale, code);
}

/// Hydrate persisted theme + locale into their providers. Called from
/// `hydratePersistedAppState` at boot. Defensive: corrupt/unknown values
/// fall back to the provider defaults (light / en) rather than throwing.
Future<void> hydrateThemeAndLocale(dynamic ref) async {
  final sp = await SharedPreferences.getInstance();
  final themeName = sp.getString(_kPrefThemeMode);
  if (themeName != null) {
    final mode = ThemeMode.values
        .where((m) => m.name == themeName)
        .cast<ThemeMode?>()
        .firstWhere((_) => true, orElse: () => null);
    if (mode != null) {
      ref.read(themeModeProvider.notifier).state = mode;
    }
  }
  final localeCode = sp.getString(_kPrefLocale);
  if (localeCode == 'hi' || localeCode == 'en') {
    ref.read(localeProvider.notifier).state = Locale(localeCode!);
  }
}