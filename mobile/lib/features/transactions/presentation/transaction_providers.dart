import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../shared/providers/auth_providers.dart';
import '../data/transaction_repository.dart';
import '../data/receipt_upload_service.dart';
import '../domain/transaction_model.dart';
import '../../../shared/models/month_key.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(firestoreProvider));
});

final receiptUploadServiceProvider = Provider<ReceiptUploadService>((ref) {
  return ReceiptUploadService(ref.watch(firebaseStorageProvider));
});

/// Currently selected month for Home / Transactions screens. Defaults to current month.
final selectedMonthKeyProvider = StateProvider<String>((ref) => MonthKey.current());

final transactionsForMonthProvider = StreamProvider<List<Transaction>>((ref) {
  final monthKey = ref.watch(selectedMonthKeyProvider);
  return ref.watch(transactionRepositoryProvider).forMonth(monthKey);
});
