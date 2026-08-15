import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dispute.dart';
import '../models/template.dart';
import 'rules_engine_repository.dart';

/// Loads the 165 template JSON assets. The `isPremium` flag on each
/// template is the AUTHORITATIVE source of Free vs Pro partitioning.
///
/// Free-tier layout (product rule): every dispute TYPE gets exactly two
/// free templates — the L1 (bank complaint) and the L2 (portal/NPCI)
/// template. Everything else is Pro. Template assets carry the two free
/// IDs per type with `"isPremium": false`; see the type→free-id table in
/// `template_repository_test.dart` which pins this invariant.
///
/// Category-vs-type note: the 5 library categories group the 7 dispute
/// types (e.g. UPI P2P / P2M / ATM / IMPS share
/// `'UPI / IMPS / ATM'`). Category-scoped flows use [matchForCategory];
/// dispute-flow flows (escalate composer, dispute detail, L2 picker) use
/// the stricter per-TYPE filter [filterForType] so a UPI dispute only
/// ever offers UPI templates, an ATM dispute only ATM ones, etc.
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

  /// Whether [t] is relevant to a dispute of [type] — the single
  /// strict type gate used by every dispute-scoped flow (Escalate auto
  /// match, template picker, dispute-detail preview, L1/L2 pickers).
  ///
  /// A FASTag dispute only ever sees `fastag_*` templates, an ATM
  /// dispute only `atm_*`, a UPI-P2P only `upi_p2p_*` + shared generic
  /// UPI helpers, etc. ID-prefix based (the template id encodes its
  /// target type).
  bool matchesType(Template t, DisputeType type) {
    final id = t.id;
    bool prefix(String p) => id.startsWith(p);
    // Generic UPI templates shared by the two UPI flavours only
    // (P2P/P2M) — chargebacks, UCPMP fraud, appellate + legal notices.
    bool genericUpi() =>
        prefix('upi_') &&
        !prefix('upi_p2p_') &&
        !prefix('upi_p2m_') &&
        id != 'upi_initial_chat_friendly_l1';
    return switch (type) {
      DisputeType.upiP2p => prefix('upi_p2p_') || genericUpi(),
      DisputeType.upiP2m =>
        prefix('upi_p2m_') ||
            genericUpi() ||
            id == 'upi_initial_chat_friendly_l1',
      DisputeType.atm => prefix('atm_'),
      // Strict: only imps_ templates. The UPI branch-visit letter is not
      // shown for IMPS (its body addresses UPI transactions).
      DisputeType.imps => prefix('imps_'),
      DisputeType.fastag => prefix('fastag_'),
      DisputeType.bankCharge => prefix('bank_charge'),
      DisputeType.wrongTransfer => prefix('wrong_transfer'),
    };
  }

  /// All templates relevant to [type], ordered by escalation level then by
  /// id. Dispute-flow screens (Escalate, dispute detail, L2 picker) use
  /// this instead of the category-wide list.
  List<Template> filterForType(List<Template> all, DisputeType type) {
    final out =
        all.where((t) => matchesType(t, type)).toList()
          ..sort((a, b) {
            final byLevel = a.escalationLevel.compareTo(b.escalationLevel);
            if (byLevel != 0) return byLevel;
            return a.id.compareTo(b.id);
          });
    return out;
  }

  /// Prefix that makes a template "own" for a type (vs. generic UPI
  /// helpers shared across types). Defaults prefer own templates so a
  /// P2P dispute opens the P2P bank complaint, not a generic branch L1.
  static String _typeOwnPrefix(DisputeType type) => switch (type) {
        DisputeType.upiP2p => 'upi_p2p_',
        DisputeType.upiP2m => 'upi_p2m_',
        DisputeType.atm => 'atm_',
        DisputeType.imps => 'imps_',
        DisputeType.fastag => 'fastag_',
        DisputeType.bankCharge => 'bank_charge',
        DisputeType.wrongTransfer => 'wrong_transfer',
      };

  /// One-tap default template for a dispute: the free L1 (bank complaint),
  /// preferring the type's own templates over generic UPI helpers, falling
  /// back to the first free template, then to the first match.
  /// Premium users get the same stable default so the composer never
  /// surprises them with a random pick.
  Template? defaultForType(List<Template> all, DisputeType type) {
    final relevant = filterForType(all, type);
    if (relevant.isEmpty) return null;
    final own =
        relevant.where((t) => t.id.startsWith(_typeOwnPrefix(type)));
    final pool = own.isNotEmpty ? own : relevant;
    for (final t in pool) {
      if (t.escalationLevel == 1 && !t.isPremium) return t;
    }
    for (final t in relevant) {
      if (!t.isPremium) return t;
    }
    return relevant.first;
  }

  /// Partition templates for [type] into (free, pro) for the escalate /
  /// dispute-detail picker. Free bucket = the per-type free templates
  /// (L1 + L2), Pro bucket = everything else, both ordered by level.
  ({List<Template> free, List<Template> pro}) splitForType(
    List<Template> all,
    DisputeType type,
  ) {
    final relevant = filterForType(all, type);
    final free = relevant.where((t) => !t.isPremium).toList();
    final pro = relevant.where((t) => t.isPremium).toList();
    return (free: free, pro: pro);
  }

  /// Auto-match kept for category-scoped UI (template library). Dispute
  /// flows should use [defaultForType]/[filterForType] instead.

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
