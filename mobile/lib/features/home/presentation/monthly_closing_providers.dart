import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/auth_providers.dart';

final monthlyClosingStatusProvider =
    StreamProvider.autoDispose.family<bool, String>(
  (ref, monthKey) {
    final uid = ref.watch(authorizedUidProvider);

    if (uid == null) {
      return Stream.value(false);
    }

    final db = ref.watch(firestoreProvider);

    return db
        .collection('monthly_closings')
        .doc(monthKey)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return false;
      }

      return doc.data()?['status'] == 'closed';
    });
  },
);
