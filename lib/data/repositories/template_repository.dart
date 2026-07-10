import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/template.dart';
import 'rules_engine_repository.dart';

/// Loads the 51 template JSON assets and merges the per-template
/// `isPremium` flag with the live-tunable `freeTemplateIds` allowlist
/// from [RulesEngine]. The free-template allowlist wins: if an id is in
/// `freeTemplateIds`, the template is unlocked regardless of what its
/// JSON says (spec §2.6.1 lets us tune this via Remote Config).
class TemplateRepository {
  List<Template>? _cached;

  Future<List<Template>> loadAll() async {
    if (_cached != null) return _cached!;
    final manifestRaw = await rootBundle.loadString(
      'assets/templates/index.json',
    );
    final manifest = jsonDecode(manifestRaw) as List<dynamic>;
    final templates = <Template>[];
    for (final path in manifest) {
      final raw = await rootBundle.loadString('assets/templates/$path');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      templates.add(Template.fromJson(json));
    }
    _cached = templates;
    return _cached!;
  }

  /// `locked = user is not premium AND id is premium AND id not in live freeTemplateIds`.
  /// If `freeTemplateIds` is empty, trust `template.isPremium` as the source
  /// of truth for free users. Premium users always unlock premium templates.
  bool isLocked(
    Template t,
    Set<String> freeIds, {
    required bool isPremiumUser,
  }) => !isPremiumUser && t.isPremium && !freeIds.contains(t.id);
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
