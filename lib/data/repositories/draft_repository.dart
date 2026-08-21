import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispute_draft.dart';

/// Persists [DisputeDraft]s locally — SharedPreferences only, no Firestore
/// sync (drafts are device-local by design; see the model doc).
///
/// Fault-tolerance contract (mirrors TemplateRepository): corrupt/missing
/// JSON yields an EMPTY LIST, never an exception to callers, so the home
/// Drafts section degrades to hidden rather than crashing the home screen.
class DraftRepository {
  static const String _prefsKey = 'dispute_drafts';

  Future<List<DisputeDraft>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      // Per-entry fault tolerance: one malformed draft must not wipe the
      // rest of the list.
      final drafts = <DisputeDraft>[];
      for (final e in decoded) {
        try {
          drafts.add(DisputeDraft.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (err) {
          debugPrint('DraftRepository: skipping malformed draft entry: $err');
        }
      }
      // Newest first for the home section.
      drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return drafts;
    } catch (e, st) {
      debugPrint('DraftRepository: loadAll failed (empty fallback): $e\n$st');
      return const [];
    }
  }

  /// Upsert by [DisputeDraft.id]; stamps `savedAt = now` so callers don't
  /// need to remember to set it.
  Future<void> save(DisputeDraft draft) async {
    final drafts = (await loadAll())
        .where((d) => d.id != draft.id)
        .toList();
    drafts.add(draft.copyWith(savedAt: DateTime.now()));
    await _persist(drafts);
  }

  Future<void> delete(String id) async {
    final drafts = (await loadAll()).where((d) => d.id != id).toList();
    await _persist(drafts);
  }

  Future<int> count() async => (await loadAll()).length;

  Future<void> _persist(List<DisputeDraft> drafts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(drafts.map((d) => d.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e, st) {
      // Persist failures (e.g. plugin unavailable in tests) must not crash
      // the create flow; log and treat the draft as best-effort.
      debugPrint('DraftRepository: persist failed: $e\n$st');
    }
  }
}

// Provider style mirrors rules_engine_repository.dart: a shared Repo
// provider + a FutureProvider family that watches it. AutoDispose so the
// home screen re-reads drafts every time it rebuilds after a save/delete.
final draftRepositoryProvider =
    Provider<DraftRepository>((ref) => DraftRepository());

final draftsProvider = FutureProvider.autoDispose<List<DisputeDraft>>(
  (ref) => ref.watch(draftRepositoryProvider).loadAll(),
);
