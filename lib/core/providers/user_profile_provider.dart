import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_profile.dart';

const _kProfileJson = 'user.profile.json';

/// Single source of truth for the complainant's identity (name, mobile,
/// email, address, place, own bank account). Persisted on-device so it
/// survives restarts; hydrated on boot by [hydratePersistedAppState].
final userProfileProvider = StateProvider<UserProfile>((ref) => UserProfile());

/// Load the persisted profile into [userProfileProvider]. Called from
/// `hydratePersistedAppState` at boot so the very first render already has
/// the saved details.
Future<UserProfile> loadPersistedUserProfile() async {
  final sp = await SharedPreferences.getInstance();
  final raw = sp.getString(_kProfileJson);
  if (raw == null || raw.isEmpty) return UserProfile.empty;
  try {
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return UserProfile.empty;
  }
}

/// Persist [profile] to SharedPreferences and update the in-memory
/// provider in one step. `ref` is dynamic so callers with either `Ref`
/// or `WidgetRef` can use it, mirroring the app_state_provider helpers.
Future<void> saveUserProfile(dynamic ref, UserProfile profile) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_kProfileJson, jsonEncode(profile.toJson()));
  try {
    if (ref is Ref) {
      ref.read(userProfileProvider.notifier).state = profile;
    } else if (ref is WidgetRef) {
      ref.read(userProfileProvider.notifier).state = profile;
    }
  } catch (_) {}
}
