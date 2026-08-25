import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/providers/auth_providers.dart';
import '../presentation/transaction_providers.dart';
import '../domain/transaction_model.dart';

enum _TypeFilter { all, expense, cashIn, mine }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _TypeFilter _typeFilter = _TypeFilter.all;
  String _search = '';
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    final monthKey = ref.watch(selectedMonthKeyProvider);
    final txAsync = ref.watch(transactionsForMonthProvider);
    final user = ref.watch(currentAppUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions — $monthKey'),
        actions: [
          txAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (transactions) => IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export to Excel',
              onPressed: () => _exportToExcel(transactions, monthKey),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter by Date Range:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                    InputChip(
                      label: Text(_selectedRange == null
                          ? 'Select Range'
                          : '${_selectedRange!.start.month}/${_selectedRange!.start.day} - ${_selectedRange!.end.month}/${_selectedRange!.end.day}'),
                      avatar: _selectedRange == null ? const Icon(Icons.calendar_today, size: 16) : null,
                      onDeleted: _selectedRange != null
                          ? () => setState(() => _selectedRange = null)
                          : null,
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _selectedRange,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedRange = picked);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_TypeFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: _TypeFilter.all, label: Text('All')),
                      ButtonSegment(value: _TypeFilter.expense, label: Text('Expense')),
                      ButtonSegment(value: _TypeFilter.cashIn, label: Text('Cash In')),
                      ButtonSegment(value: _TypeFilter.mine, label: Text('My Entries')),
                    ],
                    selected: {_typeFilter},
                    onSelectionChanged: (s) => setState(() => _typeFilter = s.first),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load transactions: $e')),
              data: (transactions) {
                final sortedList = List<Transaction>.from(transactions)
                  ..sort((a, b) {
                    final aTime = a.createdAt;
                    final bTime = b.createdAt;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                var filtered = sortedList.where((t) {
                  if (_typeFilter == _TypeFilter.expense && t.type != TxType.expense) return false;
                  if (_typeFilter == _TypeFilter.cashIn && t.type != TxType.cashIn) return false;
                  if (_typeFilter == _TypeFilter.mine && t.createdByUserId != user?.uid) return false;
                  if (_selectedRange != null) {
                    final txDate = DateTime.tryParse(t.transactionDateKey);
                    if (txDate == null) return false;
                    final start = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
                    final end = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59);
                    if (txDate.isBefore(start) || txDate.isAfter(end)) return false;
                  }
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
                    final parts = <String>[];
                    if (isCashIn) {
                      final acc = t.upworkAccountName ?? t.projectName ?? t.clientName;
                      if (acc != null && acc.isNotEmpty) parts.add(acc);
                    } else {
                      if (t.subcategoryName != null && t.subcategoryName!.isNotEmpty) {
                        parts.add(t.subcategoryName!);
                      }
                      final creator = _capitalizeWords(t.createdByName);
                      if (creator.isNotEmpty) {
                        parts.add('Created by $creator');
                      }
                    }
                    parts.add(t.transactionDateKey);

                    final subtitle = parts.join(' · ');
                    final descLine = t.description != null && t.description!.isNotEmpty
                        ? '\n${t.description}'
                        : '';
                    return ListTile(
                      leading: Icon(isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isCashIn ? Colors.green : Colors.red),
                      title: Text(title),
                      subtitle: Text('$subtitle$descLine'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MoneyText(paisa: t.amountPaisa, isCashIn: isCashIn, fontSize: 14),
                          if (t.status == 'pending')
                            const Text('Pending Reimbursement', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))
                          else if (t.lateEntry)
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

  Future<void> _exportToExcel(List<Transaction> transactions, String monthKey) async {
    try {
      final excel = Excel.createExcel();
      
      // Rename default sheet to Earnings
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Earnings');
      
      final Sheet earningsSheet = excel['Earnings'];
      final Sheet expenseSheet = excel['Expense'];

      // Add Headers
      earningsSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Source Type'),
        TextCellValue('Account Name'),
        TextCellValue('Client Name'),
        TextCellValue('Project Name'),
        TextCellValue('Amount (PKR)'),
        TextCellValue('Status'),
        TextCellValue('Created By'),
        TextCellValue('Notes'),
      ]);

      expenseSheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Subcategory'),
        TextCellValue('Payee'),
        TextCellValue('Description'),
        TextCellValue('Payment Method'),
        TextCellValue('Amount (PKR)'),
        TextCellValue('Status'),
        TextCellValue('Created By'),
        TextCellValue('Notes'),
      ]);

      // Filter and append data
      for (final t in transactions) {
        final amount = t.amountPaisa / 100.0;
        if (t.type == TxType.cashIn) {
          earningsSheet.appendRow([
            TextCellValue(t.transactionDateKey),
            TextCellValue(t.sourceType ?? ''),
            TextCellValue(t.upworkAccountName ?? ''),
            TextCellValue(t.clientName ?? ''),
            TextCellValue(t.projectName ?? ''),
            DoubleCellValue(amount),
            TextCellValue(t.status),
            TextCellValue(t.createdByName ?? ''),
            TextCellValue(t.notes ?? ''),
          ]);
        } else if (t.type == TxType.expense) {
          expenseSheet.appendRow([
            TextCellValue(t.transactionDateKey),
            TextCellValue(t.categoryName ?? ''),
            TextCellValue(t.subcategoryName ?? ''),
            TextCellValue(t.payeeName ?? ''),
            TextCellValue(t.description ?? ''),
            TextCellValue(t.paymentMethod ?? ''),
            DoubleCellValue(amount),
            TextCellValue(t.status),
            TextCellValue(t.createdByName ?? ''),
            TextCellValue(t.notes ?? ''),
          ]);
        }
      }

      // Encode and write file
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file bytes.');
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/CoreHives_Transactions_$monthKey.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // Share the file
      final xFile = XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await Share.shareXFiles([xFile], text: 'CoreHives Transactions Export - $monthKey');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  String _capitalizeWords(String? s) {
    if (s == null || s.isEmpty) return '';
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
