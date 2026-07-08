import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class RulesEngine {
  final int version;
  final Map<String, dynamic> disputeTypes;
  final Map<String, dynamic> escalationTargets;
  final List<Map<String, dynamic>> fastagIssuers;
  final Map<String, dynamic> officialLinks;
  final List<String> freeTemplateIds;

  const RulesEngine({
    required this.version,
    required this.disputeTypes,
    required this.escalationTargets,
    required this.fastagIssuers,
    required this.officialLinks,
    required this.freeTemplateIds,
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
      );

  Map<String, dynamic> ruleFor(String disputeType) =>
      disputeTypes[disputeType] as Map<String, dynamic>? ?? {};

  Map<String, dynamic> target(String key) =>
      escalationTargets[key] as Map<String, dynamic>? ?? {};
}

class RulesEngineRepository {
  RulesEngine? _cached;

  Future<RulesEngine> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/rules_engine.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _cached = RulesEngine.fromJson(json);
    return _cached!;
  }
}

final rulesEngineProvider = FutureProvider<RulesEngine>((ref) async {
  return RulesEngineRepository().load();
});

final rulesEngineRepoProvider = Provider<RulesEngineRepository>((ref) => RulesEngineRepository());
