import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';

/// Emits true if the given monthKey is closed. Missing doc = open (default).
final monthlyClosingStatusProvider = StreamProvider.family<bool, String>((ref, monthKey) {
  final db = ref.watch(firestoreProvider);
  return db.collection('monthly_closings').doc(monthKey).snapshots().map((doc) {
    if (!doc.exists) return false;
    return doc.data()?['status'] == 'closed';
  });
});
