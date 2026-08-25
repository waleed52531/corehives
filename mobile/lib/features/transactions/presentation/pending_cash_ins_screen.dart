import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../domain/transaction_model.dart';
import '../presentation/transaction_providers.dart';

class PendingCashInsScreen extends ConsumerWidget {
  const PendingCashInsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAllCashInsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Withdrawals'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    'No pending withdrawals!',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final sortedList = List<Transaction>.from(list)
            ..sort((a, b) {
              final aTime = a.createdAt;
              final bTime = b.createdAt;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          final totalAmountPaisa = sortedList.fold<int>(0, (sum, t) => sum + t.amountPaisa);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.amber.shade100, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL PENDING WITHDRAWALS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MoneyText(
                      paisa: totalAmountPaisa,
                      isCashIn: true,
                      fontSize: 26,
                    ),
                    Text(
                      'For all ${sortedList.length} pending client payments',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: sortedList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final t = sortedList[idx];
                    final accName = t.upworkAccountName ?? 'Unknown Account';
                    final owner = _getOwnerName(accName);
                    final creator = _capitalizeWords(t.createdByName);

                    final title = '$accName (Owned by $owner)';
                    final subtitle = 'Must be paid/transferred by $owner\nCreated by $creator · Date: ${t.transactionDateKey}${t.notes != null && t.notes!.isNotEmpty ? '\nNotes: ${t.notes}' : ''}';

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: Icon(Icons.arrow_downward, color: Colors.orange.shade800),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            MoneyText(paisa: t.amountPaisa, isCashIn: true, fontSize: 14),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/transactions/${t.id}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getOwnerName(String? upworkAccountName) {
    if (upworkAccountName == null) return 'Unknown';
    final accLower = upworkAccountName.toLowerCase();
    if (accLower.contains('alina')) return 'Ishtiaq';
    if (accLower.contains('abiha') || accLower.contains('zain')) return 'Zain';
    if (accLower.contains('hanzalah')) return 'Hanzalah';
    return 'Other';
  }

  String _capitalizeWords(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
