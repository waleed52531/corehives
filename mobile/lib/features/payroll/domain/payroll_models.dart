import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollEntry {
  final String id; // {monthKey}_{employeeId}
  final String employeeId;
  final String employeeName;
  final String monthKey;
  final int expectedAmountPaisa;
  final int totalPaidAmountPaisa;
  final int remainingAmountPaisa;
  final String currency;
  final String compensationType;
  final String status; // Pending | Partial | Paid | Skipped
  final String? notes;
  final Timestamp? generatedAt;
  final String? generatedByUserId;
  final Timestamp? updatedAt;

  PayrollEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.monthKey,
    required this.expectedAmountPaisa,
    required this.totalPaidAmountPaisa,
    required this.remainingAmountPaisa,
    required this.currency,
    required this.compensationType,
    required this.status,
    this.notes,
    this.generatedAt,
    this.generatedByUserId,
    this.updatedAt,
  });

  factory PayrollEntry.fromMap(String id, Map<String, dynamic> m) => PayrollEntry(
        id: id,
        employeeId: m['employeeId'] ?? '',
        employeeName: m['employeeName'] ?? '',
        monthKey: m['monthKey'] ?? '',
        expectedAmountPaisa: m['expectedAmountPaisa'] ?? 0,
        totalPaidAmountPaisa: m['totalPaidAmountPaisa'] ?? 0,
        remainingAmountPaisa: m['remainingAmountPaisa'] ?? 0,
        currency: m['currency'] ?? 'PKR',
        compensationType: m['compensationType'] ?? 'Salary',
        status: m['status'] ?? 'Pending',
        notes: m['notes'],
        generatedAt: m['generatedAt'],
        generatedByUserId: m['generatedByUserId'],
        updatedAt: m['updatedAt'],
      );
}

class PayrollPayment {
  final String id;
  final String payrollEntryId;
  final String employeeId;
  final String employeeName;
  final int amountPaisa;
  final String currency;
  final String paymentDateKey;
  final String paidByUserId;
  final String paidByUserName;
  final String? paymentMethod;
  final String? receiptUrl;
  final String? notes;
  final String linkedTransactionId;
  final Timestamp? createdAt;

  PayrollPayment({
    required this.id,
    required this.payrollEntryId,
    required this.employeeId,
    required this.employeeName,
    required this.amountPaisa,
    required this.currency,
    required this.paymentDateKey,
    required this.paidByUserId,
    required this.paidByUserName,
    this.paymentMethod,
    this.receiptUrl,
    this.notes,
    required this.linkedTransactionId,
    this.createdAt,
  });

  factory PayrollPayment.fromMap(String id, Map<String, dynamic> m) => PayrollPayment(
        id: id,
        payrollEntryId: m['payrollEntryId'] ?? '',
        employeeId: m['employeeId'] ?? '',
        employeeName: m['employeeName'] ?? '',
        amountPaisa: m['amountPaisa'] ?? 0,
        currency: m['currency'] ?? 'PKR',
        paymentDateKey: m['paymentDateKey'] ?? '',
        paidByUserId: m['paidByUserId'] ?? '',
        paidByUserName: m['paidByUserName'] ?? '',
        paymentMethod: m['paymentMethod'],
        receiptUrl: m['receiptUrl'],
        notes: m['notes'],
        linkedTransactionId: m['linkedTransactionId'] ?? '',
        createdAt: m['createdAt'],
      );
}
