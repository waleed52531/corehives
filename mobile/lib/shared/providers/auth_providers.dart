import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Raw Firebase auth state (null = signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Resolved app user doc for the signed-in Firebase user.
/// Emits null (and triggers sign-out) if the user record is missing or inactive.
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return Stream.value(null);

  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('users').doc(authState.uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    final user = AppUser.fromMap(doc.id, doc.data()!);
    if (!user.active) {
      ref.read(firebaseAuthProvider).signOut();
      return null;
    }
    return user;
  });
});

class AuthRepository {
  final FirebaseAuth _auth;
  AuthRepository(this._auth);

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(firebaseAuthProvider)));
