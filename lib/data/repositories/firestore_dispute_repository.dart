import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:refund_radar/data/models/dispute.dart';

abstract class DisputeRepository {
  Future<List<Dispute>> loadDisputes(String uid);
  Future<Dispute> saveDispute(String uid, Dispute dispute);
  Future<void> deleteDispute(String uid, String id);
  Future<void> deleteAllUserData(String uid);
}

class FirestoreDisputeRepository implements DisputeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('disputes');

  @override
  Future<List<Dispute>> loadDisputes(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => Dispute.fromJson(d.data()..['id'] = d.id)).toList();
  }

  @override
  Future<Dispute> saveDispute(String uid, Dispute dispute) async {
    final data = dispute.toJson()..['uid'] = uid;
    if (dispute.id.isEmpty) {
      final ref = await _col(uid).add(data);
      return dispute.copyWith(id: ref.id, uid: uid);
    }
    await _col(uid).doc(dispute.id).set(data, SetOptions(merge: true));
    return dispute.copyWith(uid: uid);
  }

  @override
  Future<void> deleteDispute(String uid, String id) async {
    await _col(uid).doc(id).delete();
  }

  @override
  Future<void> deleteAllUserData(String uid) async {
    final snap = await _col(uid).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _db.collection('users').doc(uid).delete();
  }
}
