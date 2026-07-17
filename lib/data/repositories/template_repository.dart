import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dispute.dart';
import '../models/template.dart';
import 'rules_engine_repository.dart';

/// Loads the 52 template JSON assets. The `isPremium` flag on each
/// template is the AUTHORITATIVE source of Free vs Pro partitioning;
/// it is intentionally NOT merged with `freeTemplateIds` because that
/// would let a Remote Config tweak repaint a Premium template as Free.
/// (The `freeTemplateIds` allowlist is used only as a *display*
/// shortcut via [TemplateRepository.isLocked] so a non-premium user
/// can preview one level up from their plan; see [matchForCategory].)
class TemplateRepository {
  List<Template>? _cached;

  Future<List<Template>> loadAll() async {
    if (_cached != null) return _cached!;
    final templates = <Template>[];
    try {
      final manifestRaw = await rootBundle.loadString(
        'assets/templates/index.json',
      );
      final manifest = jsonDecode(manifestRaw) as List<dynamic>;
      // Per-file fault tolerance: one malformed/missing template asset
      // (build merge conflict, bad Remote Config path override, encoding
      // glitch) must NOT render the entire template library unusable.
      // Skip the bad file, log, and keep the rest — callers degrade to
      // "no template for this category" rather than a full-screen error.
      for (final path in manifest) {
        try {
          final raw = await rootBundle.loadString('assets/templates/$path');
          final json = jsonDecode(raw) as Map<String, dynamic>;
          templates.add(Template.fromJson(json));
        } catch (e, st) {
          debugPrint('TemplateRepository: skipping malformed asset '
              'assets/templates/$path: $e\n$st');
        }
      }
    } catch (e, st) {
      // Manifest itself missing/corrupt — return the empty list so callers
      // show their empty state rather than crashing. Logged for release
      // observability via Crashlytics breadcrumb upstream.
      debugPrint('TemplateRepository: could not load template index: $e\n$st');
    }
    _cached = templates;
    return _cached!;
  }

  /// Whether [t] should be shown as locked for the current user. Pure
  /// function of the user's premium state and the template's own JSON
  /// `isPremium` flag — partition ownership lives on [Template] itself.
  /// `freeIds` is no longer consulted: see the class doc for why.
  bool isLocked(
    Template t,
    Set<String> freeIds, {
    required bool isPremiumUser,
  }) => t.isPremium && !isPremiumUser;

  // ME-7: the level-2 category label shared by every template-matching
  // call site (Escalate auto-match, dispute-detail preview, and the L2
  // picker). Centralising it removes the duplicated `switch (d.type)`
  // blocks that had drifted in casing / labels.
  static String categoryFor(DisputeType type) => switch (type) {
        DisputeType.upiP2p ||
        DisputeType.upiP2m ||
        DisputeType.atm ||
        DisputeType.imps =>
          'UPI / IMPS / ATM',
        DisputeType.fastag => 'FASTag',
        DisputeType.bankCharge => 'Bank charges',
        DisputeType.wrongTransfer => 'Wrong transfer',
      };

  /// ME-7: auto-match a single level-[level] template for [type] using the
  /// 3-tier fallback (unlocked for this user → free in category → any in
  /// category). Mirrors the old `_matchEscalationTemplate` /
  /// `_matchDisputeTemplate` logic but in one place so the two screens
  /// never drift. `level` defaults to 2 (the L2 escalation row).
  Template? matchForCategory(
    List<Template> all,
    DisputeType type,
    Set<String> freeIds, {
    required bool isPremiumUser,
    int level = 2,
  }) {
    final category = categoryFor(type);
    final sameRow =
        all.where((t) => t.escalationLevel == level && t.category == category);
    // 1. Unlocked (free) for this user first so the auto-match never leaks.
    for (final t in sameRow) {
      if (!isLocked(t, freeIds, isPremiumUser: isPremiumUser)) return t;
    }
    // 2. Any free (non-premium) template in the row.
    for (final t in sameRow) {
      if (!t.isPremium) return t;
    }
    // 3. Last resort: any template in the row (may be locked; callers
    //    handle gating).
    for (final t in sameRow) {
      return t;
    }
    return null;
  }

  /// ME-7: partition the level-[level] templates for [type] into (free, pro)
  /// buckets for the L2 picker. Used by the escalate picker and the
  /// dispute-detail in-app template picker.
  ///
  /// IMPORTANT: partition is driven entirely by the template's OWN
  /// `isPremium` flag (`t.isPremium == false` → Free tab,
  /// `t.isPremium == true` → Pro tab). This is the fix for the bug where
  /// the Pro tab was empty after a successful purchase — previously this
  /// function routed templates to Free vs Pro based on the user's lock
  /// state, so a Premium user saw ALL templates under Free and an empty
  /// Pro tab. `isPremiumUser` is kept in the signature for callers that
  /// want a single-flat-list for Premium users (see
  /// [singleFlatListForPremiumUsers]).
  ({List<Template> free, List<Template> pro}) splitForCategory(
    List<Template> all,
    DisputeType type,
    Set<String> freeIds, {
    required bool isPremiumUser,
    int level = 2,
  }) {
    final category = categoryFor(type);
    final free = <Template>[];
    final pro = <Template>[];
    for (final t in all) {
      if (t.escalationLevel != level || t.category != category) continue;
      if (t.isPremium) {
        pro.add(t);
      } else {
        free.add(t);
      }
    }
    return (free: free, pro: pro);
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(),
);

/// All 51 templates (premium AND free) — caller is responsible for the
/// lock-decision via [TemplateRepository.isLocked] using the allowlist
/// from [rulesEngineProvider].
final templatesProvider = FutureProvider<List<Template>>((ref) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.loadAll();
});
