import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Firebase Authentication state.
///
/// Emits:
/// - User when logged in
/// - null when logged out
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Default Firestore profile for a newly authenticated user.
///
/// IMPORTANT:
/// New users are NEVER automatically admins.
Map<String, dynamic> _defaultUserProfile(User user) {
  final email = user.email ?? '';

  String name = user.displayName?.trim() ?? '';

  if (name.isEmpty) {
    if (email.contains('@')) {
      name = email.split('@').first;
    } else {
      name = 'User';
    }
  }

  return {
    'active': true,
    'role': 'member',
    'name': name,
    'email': email,
    'permissions': {
      'viewPayroll': true,
      'managePayroll': false,
      'viewEmployees': true,
      'manageEmployees': false,
      'viewReports': true,
    },
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'createdByUserId': user.uid,
    'updatedByUserId': user.uid,
  };
}

/// Ensures that the Firebase Authentication user also has a
/// matching Firestore document:
///
/// users/{FirebaseAuth UID}
///
/// This replaces the need to manually create a user document
/// from Firebase Console.
Future<void> _ensureUserProfile(
  FirebaseFirestore firestore,
  User firebaseUser,
) async {
  final userRef = firestore.collection('users').doc(firebaseUser.uid);

  final snapshot = await userRef.get();

  // Never overwrite an existing user's role/permissions.
  if (snapshot.exists) {
    return;
  }

  await userRef.set(
    _defaultUserProfile(firebaseUser),
  );
}

/// Watches ONE specific Firebase UID.
///
/// This is intentionally a family provider.
///
/// Example:
///
/// User A -> appUserByUidProvider(A)
///
/// When User B logs in:
///
/// User B -> appUserByUidProvider(B)
///
/// This prevents stale User A data from being reused for User B.
final appUserByUidProvider =
    StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) async* {
    final auth = ref.watch(firebaseAuthProvider);
    final firestore = ref.watch(firestoreProvider);

    final firebaseUser = auth.currentUser;

    // The requested profile must belong to the current Firebase user.
    if (firebaseUser == null || firebaseUser.uid != uid) {
      yield null;
      return;
    }

    // Automatically create users/{uid} on first login.
    await _ensureUserProfile(
      firestore,
      firebaseUser,
    );

    final userRef = firestore.collection('users').doc(uid);

    await for (final doc in userRef.snapshots()) {
      // Stop this provider immediately if Firebase Auth switches users.
      final currentFirebaseUser = auth.currentUser;

      if (currentFirebaseUser == null || currentFirebaseUser.uid != uid) {
        break;
      }

      if (!doc.exists) {
        yield null;
        continue;
      }

      final appUser = AppUser.fromMap(
        doc.id,
        doc.data()!,
      );

      // Inactive users should not remain logged in.
      if (!appUser.active) {
        await auth.signOut();
        yield null;
        break;
      }

      yield appUser;
    }
  },
);

/// Resolves the Firestore profile belonging ONLY to the
/// currently authenticated Firebase user.
///
/// This provider changes to a different family-provider instance
/// whenever the Firebase UID changes.
final currentAppUserProvider = Provider<AsyncValue<AppUser?>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    loading: () {
      return const AsyncValue<AppUser?>.loading();
    },
    error: (error, stackTrace) {
      return AsyncValue<AppUser?>.error(
        error,
        stackTrace,
      );
    },
    data: (firebaseUser) {
      if (firebaseUser == null) {
        return const AsyncValue<AppUser?>.data(null);
      }

      return ref.watch(
        appUserByUidProvider(firebaseUser.uid),
      );
    },
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(
    this._auth,
    this._firestore,
  );

  Future<void> signIn(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Unable to resolve Firebase user.',
      );
    }

    try {
      // Make sure the Firestore profile exists before login
      // is considered complete.
      await _ensureUserProfile(
        _firestore,
        firebaseUser,
      );
    } catch (_) {
      // Don't leave a partially authenticated session behind.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(
    String email,
  ) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

final authorizedUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUserState = ref.watch(currentAppUserProvider);

  final firebaseUser = authState.asData?.value;
  final appUser = appUserState.asData?.value;

  if (firebaseUser == null || appUser == null) {
    return null;
  }

  if (firebaseUser.uid != appUser.uid) {
    return null;
  }

  if (!appUser.active) {
    return null;
  }

  return firebaseUser.uid;
});
