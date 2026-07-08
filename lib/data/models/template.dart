import 'package:flutter/foundation.dart';

/// One exhibit in the template library (spec §2.6.1).
///
/// Each template is a thin data holder: the binary ships 51 of these as
/// individual JSON files under `assets/templates/{category}/*.json`. Both
/// English and Hindi bodies MUST be present — the library toggles language
/// at view time.
///
/// `isPremium` here is the AUTHORITATIVE flag from JSON. Callers MUST also
/// respect the `freeTemplateIds` live-tunable list from `rules_engine.json`
/// (spec §2.6.1 last paragraph: "The free-template ID list lives in
/// rules_engine.json so it can be tuned via Remote Config without an app
/// update"). The repository merges the two — see
/// `TemplateRepository.isLocked`.
@immutable
class Template {
  /// Stable machine id, e.g. `upi_p2p_bank_complaint`. Used as the key for
  /// the `freeTemplateIds` allowlist in `rules_engine.json`.
  final String id;

  /// English title shown in the library list / preview header.
  final String titleEn;

  /// Hindi title. Required for every template (spec §2.6.1).
  final String titleHi;

  /// One of: `UPI / IMPS / ATM`, `FASTag`, `Bank charges`,
  /// `Wrong transfer`, `Advanced / legal` — spec §2.6.1 catalog.
  final String category;

  /// Numeric escalation level (1 = bank, 2 = portal/NPCI, 3 = Ombudsman,
  /// 4 = consumer court / RTI, 5 = appellate).
  final int escalationLevel;

  /// Whether this template is premium-only in JSON. The actual unlock
  /// decision is `!freeTemplateIds.contains(id) && isPremium`.
  final bool isPremium;

  /// English body with `{PLACEHOLDER}` tokens (UTR, AMOUNT, …).
  final String bodyEn;

  /// Hindi body, same placeholders.
  final String bodyHi;

  const Template({
    required this.id,
    required this.titleEn,
    required this.titleHi,
    required this.category,
    required this.escalationLevel,
    required this.isPremium,
    required this.bodyEn,
    required this.bodyHi,
  });

  factory Template.fromJson(Map<String, dynamic> json) => Template(
        id: json['id'] as String,
        titleEn: json['titleEn'] as String,
        titleHi: json['titleHi'] as String,
        category: json['category'] as String,
        escalationLevel: (json['escalationLevel'] as num).toInt(),
        isPremium: json['isPremium'] as bool? ?? false,
        bodyEn: json['bodyEn'] as String,
        bodyHi: json['bodyHi'] as String,
      );

  /// Returns the localized title for the given locale code (`'en'`/`'hi'`).
  String titleFor(String locale) =>
      locale == 'hi' ? titleHi : titleEn;

  /// Returns the localized body for the given locale code.
  String bodyFor(String locale) =>
      locale == 'hi' ? bodyHi : bodyEn;

  /// Substitutes every `{TOKEN}` placeholder in [body] with the value
  /// found in [values]; tokens not in the map are kept verbatim so the
  /// user can spot-missed fields.
  static String fill(String body, Map<String, String> values) {
    var out = body;
    values.forEach((k, v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }
}
