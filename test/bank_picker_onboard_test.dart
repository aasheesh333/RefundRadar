import 'package:flutter_test/flutter_test.dart';
import 'package:refund_radar/data/constants/bank_catalog.dart';
import 'package:refund_radar/features/dispute_create/dispute_form_page.dart';
import 'package:refund_radar/features/dispute_create/fallback_banks.dart';

void main() {
  group('mergeOnboardBanksWithFallback', () {
    test('selected empty → returns fallback only', () {
      final result = mergeOnboardBanksWithFallback(
        selectedIds: const [],
        catalog: BankCatalog.banks,
        fallback: kFallbackBanks,
      );
      expect(result, kFallbackBanks);
    });

    test('selected banks appear first with catalog names', () {
      final result = mergeOnboardBanksWithFallback(
        selectedIds: const ['kotak', 'yes'],
        catalog: BankCatalog.banks,
        fallback: kFallbackBanks,
      );
      expect(result.first.id, 'kotak');
      expect(result.first.name, 'Kotak Mahindra Bank');
      expect(result[1].id, 'yes');
      expect(result[1].name, 'Yes Bank');
      // fallback banks not already selected follow
      final ids = result.map((b) => b.id).toList();
      expect(ids.indexOf('kotak'), lessThan(ids.indexOf('hdfc')));
      expect(ids, containsAll(['hdfc', 'icici', 'axis', 'sbi', 'other']));
    });

    test('selected id also in fallback is not duplicated', () {
      final result = mergeOnboardBanksWithFallback(
        selectedIds: const ['hdfc', 'sbi'],
        catalog: BankCatalog.banks,
        fallback: kFallbackBanks,
      );
      final hdfcCount = result.where((b) => b.id == 'hdfc').length;
      final sbiCount = result.where((b) => b.id == 'sbi').length;
      expect(hdfcCount, 1);
      expect(sbiCount, 1);
      // catalog name preferred for selected sbi
      expect(result.firstWhere((b) => b.id == 'sbi').name, 'State Bank of India');
    });

    test('unknown selected ids are skipped', () {
      final result = mergeOnboardBanksWithFallback(
        selectedIds: const ['not-a-bank', 'hdfc'],
        catalog: BankCatalog.banks,
        fallback: kFallbackBanks,
      );
      expect(result.map((b) => b.id), isNot(contains('not-a-bank')));
      expect(result.first.id, 'hdfc');
    });
  });
}
