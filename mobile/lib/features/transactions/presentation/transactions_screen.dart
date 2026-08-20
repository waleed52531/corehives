import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../presentation/transaction_providers.dart';
import '../domain/transaction_model.dart';

enum _TypeFilter { all, expense, cashIn }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _TypeFilter _typeFilter = _TypeFilter.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final monthKey = ref.watch(selectedMonthKeyProvider);
    final txAsync = ref.watch(transactionsForMonthProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Transactions — $monthKey')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search description, category, payee...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SegmentedButton<_TypeFilter>(
                  segments: const [
                    ButtonSegment(value: _TypeFilter.all, label: Text('All')),
                    ButtonSegment(value: _TypeFilter.expense, label: Text('Expense')),
                    ButtonSegment(value: _TypeFilter.cashIn, label: Text('Cash In')),
                  ],
                  selected: {_typeFilter},
                  onSelectionChanged: (s) => setState(() => _typeFilter = s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load transactions: $e')),
              data: (transactions) {
                var filtered = transactions.where((t) {
                  if (_typeFilter == _TypeFilter.expense && t.type != TxType.expense) return false;
                  if (_typeFilter == _TypeFilter.cashIn && t.type != TxType.cashIn) return false;
                  if (_search.isEmpty) return true;
                  final haystack = [
                    t.description, t.notes, t.categoryName, t.subcategoryName,
                    t.payeeName, t.projectName, t.sourceType, t.upworkAccountName,
                  ].whereType<String>().join(' ').toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No transactions match.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final isCashIn = t.type == TxType.cashIn;
                    final title = isCashIn ? (t.sourceType ?? 'Cash In') : (t.categoryName ?? 'Expense');
                    final subtitle = isCashIn
                        ? (t.upworkAccountName ?? t.projectName ?? t.clientName ?? '')
                        : (t.subcategoryName ?? '');
                    return ListTile(
                      leading: Icon(isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isCashIn ? Colors.green : Colors.red),
                      title: Text(title),
                      subtitle: Text('$subtitle · ${t.transactionDateKey}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(paisa: t.amountPaisa, isCashIn: isCashIn, fontSize: 14),
                          if (t.lateEntry)
                            const Text('Late Entry', style: TextStyle(fontSize: 10, color: Colors.orange)),
                        ],
                      ),
                      onTap: () => context.push('/transactions/${t.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
