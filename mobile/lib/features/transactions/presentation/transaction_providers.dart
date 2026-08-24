import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../shared/providers/auth_providers.dart';
import '../../../shared/models/month_key.dart';

import '../data/transaction_repository.dart';
import '../data/receipt_upload_service.dart';
import '../domain/transaction_model.dart';
import '../../config/domain/config_models.dart';
import '../../config/presentation/config_providers.dart';

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

final allTransactionsSinceBackupProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).activeSince('2026-08-10');
});

class MonthlyBalances {
  final int openingBalancePaisa;
  final int cashInPaisa;
  final int expensePaisa;
  final int closingBalancePaisa;

  MonthlyBalances({
    required this.openingBalancePaisa,
    required this.cashInPaisa,
    required this.expensePaisa,
    required this.closingBalancePaisa,
  });
}

final monthlyBalancesProvider = Provider.family<AsyncValue<MonthlyBalances>, String>((ref, monthKey) {
  final transactionsAsync = ref.watch(allTransactionsSinceBackupProvider);
  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (list) {
      // Base backup: August 10, 2026 -> PKR 2,398,060 = 239,806,000 paisa
      const baseBalancePaisa = 239806000;

      final sorted = List<Transaction>.from(list)
        ..sort((a, b) => a.transactionDateKey.compareTo(b.transactionDateKey));

      int runningBalance = baseBalancePaisa;
      int currentMonthCashIn = 0;
      int currentMonthExpense = 0;
      int openingBalance = baseBalancePaisa;

      for (final tx in sorted) {
        if (tx.status.toLowerCase() != 'completed' && tx.type == TxType.cashIn) {
          continue;
        }

        final txMonthKey = tx.monthKey;

        if (txMonthKey.compareTo(monthKey) < 0) {
          if (tx.type == TxType.cashIn) {
            runningBalance += tx.amountPaisa;
          } else if (tx.type == TxType.expense) {
            runningBalance -= tx.amountPaisa;
          }
        }
      }

      openingBalance = runningBalance;

      for (final tx in sorted) {
        if (tx.status.toLowerCase() != 'completed' && tx.type == TxType.cashIn) {
          continue;
        }

        final txMonthKey = tx.monthKey;

        if (txMonthKey == monthKey) {
          if (tx.type == TxType.cashIn) {
            currentMonthCashIn += tx.amountPaisa;
            runningBalance += tx.amountPaisa;
          } else if (tx.type == TxType.expense) {
            currentMonthExpense += tx.amountPaisa;
            runningBalance -= tx.amountPaisa;
          }
        }
      }

      return AsyncValue.data(MonthlyBalances(
        openingBalancePaisa: openingBalance,
        cashInPaisa: currentMonthCashIn,
        expensePaisa: currentMonthExpense,
        closingBalancePaisa: runningBalance,
      ));
    },
  );
});

final pendingUserWithdrawalsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final user = ref.watch(currentAppUserProvider).value;
  if (user == null) return Stream.value([]);

  final accountsAsync = ref.watch(activeUpworkAccountsProvider);
  final repo = ref.watch(transactionRepositoryProvider);

  return repo.pendingCashIns().map((list) {
    final accounts = accountsAsync.value ?? [];
    return list.where((t) {
      if (t.upworkAccountId == null) return false;

      UpworkAccount? acc;
      try {
        acc = accounts.firstWhere((a) => a.id == t.upworkAccountId);
      } catch (_) {}

      if (acc != null && acc.ownerName != null) {
        final nameLower = user.name.toLowerCase();
        final ownerLower = acc.ownerName!.toLowerCase();
        return nameLower.contains(ownerLower) || ownerLower.contains(nameLower);
      }

      final nameLower = user.name.toLowerCase();
      final accNameLower = (t.upworkAccountName ?? '').toLowerCase();
      if (nameLower.contains('ishtiaq') && accNameLower.contains('alina')) return true;
      if (nameLower.contains('zain') && (accNameLower.contains('abiha') || accNameLower.contains('zain'))) return true;
      if (nameLower.contains('hanzalah') && accNameLower.contains('hanzalah')) return true;
      return false;
    }).toList();
  });
});

final pendingReimbursementsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.pendingReimbursements();
});

