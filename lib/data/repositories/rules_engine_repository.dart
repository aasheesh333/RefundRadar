import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

@immutable
class RulesEngine {
  final int version;
  final Map<String, dynamic> disputeTypes;
  final Map<String, dynamic> escalationTargets;
  final List<Map<String, dynamic>> fastagIssuers;
  final Map<String, dynamic> officialLinks;
  final List<String> freeTemplateIds;
  final List<String> holidayStrings;

  const RulesEngine({
    required this.version,
    required this.disputeTypes,
    required this.escalationTargets,
    required this.fastagIssuers,
    required this.officialLinks,
    required this.freeTemplateIds,
    required this.holidayStrings,
  });

  factory RulesEngine.fromJson(Map<String, dynamic> json) => RulesEngine(
        version: json['version'] as int? ?? 1,
        disputeTypes: Map<String, dynamic>.from(json['disputeTypes'] ?? {}),
        escalationTargets: Map<String, dynamic>.from(json['escalationTargets'] ?? {}),
        fastagIssuers: (json['fastagIssuers'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        officialLinks: Map<String, dynamic>.from(json['officialLinks'] ?? {}),
        freeTemplateIds: List<String>.from(json['freeTemplateIds'] ?? []),
        holidayStrings: List<String>.from(json['holidays'] ?? []),
      );

  /// Parsed holiday dates (midnight-normalised) for the working-day
  /// calendar. Empty when no holidays are declared. Parse failures on
  /// individual entries are skipped (a single bad date string must not
  /// break TAT computation for every dispute).
  Set<DateTime> get holidayDates => holidayStrings
      .map((s) => DateTime.tryParse(s))
      .whereType<DateTime>()
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  Map<String, dynamic> ruleFor(String disputeType) =>
      disputeTypes[disputeType] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> target(String key) =>
      escalationTargets[key] as Map<String, dynamic>? ?? {};
}

class RulesEngineRepository {
  RulesEngine? _cached;
  // B7: Remote Config key + minimum fetch interval (12h — spec §6.5 says
  //     "Rules engine overrides via Remote Config" with daily cadence; 12h
  //     is a safe compromise).
  static const String _remoteKey = 'rules_engine_override';
  static const Duration _minFetchInterval = Duration(hours: 12);

  /// Load rules engine with optional Remote Config overlay (B7).
  ///
  /// Behaviour:
  ///   1. Always read bundled `assets/rules_engine.json` first — guarantees
  ///      a valid baseline even with no network / no Firebase.
  ///   2. If Firebase Remote Config is reachable AND a JSON payload with a
  ///      `version` strictly GREATER than the bundled one is present, the
  ///      Remote Config value is merged on top (shallow merge per top-level
  ///      key — Remote Config wins for any key it specifies).
  ///   3. Cache the merged result so subsequent [load] calls are free.
  Future<RulesEngine> load() async {
    if (_cached != null) return _cached!;

    // ---- Step 1: bundled baseline ----
    var json = <String, dynamic>{};
    RulesEngine engine = RulesEngine.fromJson(json);
    try {
      final raw = await rootBundle.loadString('assets/rules_engine.json');
      json = jsonDecode(raw) as Map<String, dynamic>;
      engine = RulesEngine.fromJson(json);
    } catch (e, st) {
      // Bundled baseline missing/corrupt (build corruption, accidental
      // asset deletion). Fall back to an empty engine so rules-driven
      // screens degrade to "no rules" empty states rather than crashing
      // the whole app. The Remote Config overlay below can still replace
      // this with a real engine if one is published.
      debugPrint('RulesEngineRepository: bundled baseline parse failed '
          '(using empty fallback): $e\n$st');
    }

    // ---- Step 2: Remote Config overlay ----
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: _minFetchInterval,
      ));
      // activate(); fetches + activates the latest RC values, falling back
      // to last-activated values if the network round-trip fails.
      // Returns `true` when at least one RC value changed since last fetch.
      final updated = await rc.fetchAndActivate();
      if (updated) {
        final overrideStr = rc.getString(_remoteKey);
        if (overrideStr.isNotEmpty) {
          final overrideJson = jsonDecode(overrideStr) as Map<String, dynamic>;
          final overrideEngine = RulesEngine.fromJson(overrideJson);
          // Only apply if strictly newer — protects against stale RC values
          // being served after a fresh bundle ships with a higher version.
          if (overrideEngine.version > engine.version) {
            // Deep-merge: RC overlay wins for keys it specifies, but nested
            // maps (e.g. disputeTypes.upi_p2p) keep bundled fields that the
            // override didn't re-declare. Prevents a partial RC payload from
            // wiping entire dispute-type rules.
            json = deepMerge(json, overrideJson);
            engine = RulesEngine.fromJson(json);
          }
        }
      }
    } catch (e) {
      // Remote Config failures are NOT fatal — fall back to baseline.
      debugPrint('Remote Config overlay skipped: $e');
    }

    _cached = engine;
    return _cached!;
  }

  /// Force a re-read on next [load] (e.g. after a "Refresh rules" action
  /// in settings). Clears the in-memory cache AND the Remote Config cache
  /// so the next fetch actually hits the network.
  Future<void> invalidate() async {
    _cached = null;
    try {
      await FirebaseRemoteConfig.instance.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // bypass interval next load
      ));
    } catch (_) {/* not initialised in dev/test — fine */}
  }

  /// Recursively merge [overlay] into [base]. Overlay values win; when both
  /// sides have a Map at the same key, recurse instead of replacing the
  /// whole map. Lists and scalars are replaced wholesale.
  static Map<String, dynamic> deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overlay,
  ) {
    final out = Map<String, dynamic>.from(base);
    overlay.forEach((key, value) {
      final existing = out[key];
      if (existing is Map && value is Map) {
        out[key] = deepMerge(
          Map<String, dynamic>.from(existing),
          Map<String, dynamic>.from(value),
        );
      } else {
        out[key] = value;
      }
    });
    return out;
  }
}

// Use the shared `rulesEngineRepoProvider` instance (not a freshly-built
// `RulesEngineRepository()`) so `invalidate()` clears the SAME cache that
// `load()` populates. Previously each provider constructed its own repo
// with its own `_cached`, so a Settings "Refresh rules" invalidate was a
// no-op against the provider the UI reads from.
final rulesEngineProvider = FutureProvider<RulesEngine>((ref) async {
  return ref.watch(rulesEngineRepoProvider).load();
});

final rulesEngineRepoProvider = Provider<RulesEngineRepository>((ref) => RulesEngineRepository());
