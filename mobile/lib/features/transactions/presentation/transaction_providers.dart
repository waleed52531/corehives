import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../../shared/models/month_key.dart';

import '../data/transaction_repository.dart';
import '../data/receipt_upload_service.dart';
import '../domain/transaction_model.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(firestoreProvider),
  );
});

final receiptUploadServiceProvider = Provider<ReceiptUploadService>((ref) {
  return ReceiptUploadService(
    ref.watch(firebaseStorageProvider),
  );
});

/// Currently selected month for Home / Transactions.
final selectedMonthKeyProvider = StateProvider<String>((ref) {
  return MonthKey.current();
});

final transactionsForMonthProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final uid = ref.watch(authorizedUidProvider);

  final monthKey = ref.watch(selectedMonthKeyProvider);

  // IMPORTANT:
  // Don't create a Firestore listener while users are switching.
  if (uid == null) {
    return Stream.value(
      const <Transaction>[],
    );
  }

  final repository = ref.watch(transactionRepositoryProvider);

  return repository.forMonth(monthKey);
});
