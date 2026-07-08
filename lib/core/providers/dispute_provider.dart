import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:refund_radar/data/models/dispute.dart';
import 'package:refund_radar/data/repositories/firestore_dispute_repository.dart';

final disputeRepositoryProvider =
    Provider<FirestoreDisputeRepository>((ref) => FirestoreDisputeRepository());

final disputesProvider =
    FutureProvider.family<List<Dispute>, String>((ref, uid) async {
  final repo = ref.watch(disputeRepositoryProvider);
  return repo.loadDisputes(uid);
});
