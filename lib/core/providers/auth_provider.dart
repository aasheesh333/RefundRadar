import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final userIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);
  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      try {
        final cred = await auth.signInAnonymously();
        yield cred.user?.uid;
      } catch (_) {
        yield null;
      }
    } else {
      yield user.uid;
    }
  }
});
