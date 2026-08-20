import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { expense, cashIn }
enum AttachmentStatus { none, pending, uploaded, failed }

TxType txTypeFromString(String s) => s == 'cash_in' ? TxType.cashIn : TxType.expense;
String txTypeToString(TxType t) => t == TxType.cashIn ? 'cash_in' : 'expense';

AttachmentStatus attachmentStatusFromString(String? s) {
  switch (s) {
    case 'pending':
      return AttachmentStatus.pending;
    case 'uploaded':
      return AttachmentStatus.uploaded;
    case 'failed':
      return AttachmentStatus.failed;
    default:
      return AttachmentStatus.none;
  }
}

class Transaction {
  final String id;
  final TxType type;
  final String? sourceType; // cash_in only: Upwork | Front Sale | PayPal | Direct Client | Fiverr | Other
  final int amountPaisa;
  final String currency; // always 'PKR' in V1

  final String? categoryId;
  final String? categoryName;
  final String? subcategoryId;
  final String? subcategoryName;

  final String? payeeId;
  final String? payeeName;

  final String? projectId;
  final String? projectName;

  final String? employeeId;
  final String? employeeName;

  final String? upworkAccountId;
  final String? upworkAccountName;

  final String? salespersonEmployeeId;
  final String? salespersonName;
  final String? clientName;

  final String paidByUserId;
  final String paidByUserName;
  final String? paymentMethod;

  final String transactionDateKey; // YYYY-MM-DD
  final String monthKey; // YYYY-MM

  final String status; // completed | pending | failed | cancelled
  final String? attachmentUrl;
  final String? attachmentStoragePath;
  final AttachmentStatus attachmentStatus;

  final String? description;
  final String? notes;

  final bool lateEntry;
  final String? lateEntryReason;
  final String? originalMonthKey;

  final String createdByUserId;
  final String createdByName;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? deletedAt;
  final String? deletedByUserId;

  Transaction({
    required this.id,
    required this.type,
    this.sourceType,
    required this.amountPaisa,
    this.currency = 'PKR',
    this.categoryId,
    this.categoryName,
    this.subcategoryId,
    this.subcategoryName,
    this.payeeId,
    this.payeeName,
    this.projectId,
    this.projectName,
    this.employeeId,
    this.employeeName,
    this.upworkAccountId,
    this.upworkAccountName,
    this.salespersonEmployeeId,
    this.salespersonName,
    this.clientName,
    required this.paidByUserId,
    required this.paidByUserName,
    this.paymentMethod,
    required this.transactionDateKey,
    required this.monthKey,
    required this.status,
    this.attachmentUrl,
    this.attachmentStoragePath,
    this.attachmentStatus = AttachmentStatus.none,
    this.description,
    this.notes,
    this.lateEntry = false,
    this.lateEntryReason,
    this.originalMonthKey,
    required this.createdByUserId,
    required this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedByUserId,
  });

  factory Transaction.fromMap(String id, Map<String, dynamic> m) => Transaction(
        id: id,
        type: txTypeFromString(m['type'] ?? 'expense'),
        sourceType: m['sourceType'],
        amountPaisa: m['amountPaisa'] ?? 0,
        currency: m['currency'] ?? 'PKR',
        categoryId: m['categoryId'],
        categoryName: m['categoryName'],
        subcategoryId: m['subcategoryId'],
        subcategoryName: m['subcategoryName'],
        payeeId: m['payeeId'],
        payeeName: m['payeeName'],
        projectId: m['projectId'],
        projectName: m['projectName'],
        employeeId: m['employeeId'],
        employeeName: m['employeeName'],
        upworkAccountId: m['upworkAccountId'],
        upworkAccountName: m['upworkAccountName'],
        salespersonEmployeeId: m['salespersonEmployeeId'],
        salespersonName: m['salespersonName'],
        clientName: m['clientName'],
        paidByUserId: m['paidByUserId'] ?? '',
        paidByUserName: m['paidByUserName'] ?? '',
        paymentMethod: m['paymentMethod'],
        transactionDateKey: m['transactionDateKey'] ?? '',
        monthKey: m['monthKey'] ?? '',
        status: m['status'] ?? 'completed',
        attachmentUrl: m['attachmentUrl'],
        attachmentStoragePath: m['attachmentStoragePath'],
        attachmentStatus: attachmentStatusFromString(m['attachmentStatus']),
        description: m['description'],
        notes: m['notes'],
        lateEntry: m['lateEntry'] ?? false,
        lateEntryReason: m['lateEntryReason'],
        originalMonthKey: m['originalMonthKey'],
        createdByUserId: m['createdByUserId'] ?? '',
        createdByName: m['createdByName'] ?? '',
        createdAt: m['createdAt'],
        updatedAt: m['updatedAt'],
        deletedAt: m['deletedAt'],
        deletedByUserId: m['deletedByUserId'],
      );

  Map<String, dynamic> toCreateMap() => {
        'type': txTypeToString(type),
        if (sourceType != null) 'sourceType': sourceType,
        'amountPaisa': amountPaisa,
        'currency': currency,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryName != null) 'categoryName': categoryName,
        if (subcategoryId != null) 'subcategoryId': subcategoryId,
        if (subcategoryName != null) 'subcategoryName': subcategoryName,
        if (payeeId != null) 'payeeId': payeeId,
        if (payeeName != null) 'payeeName': payeeName,
        if (projectId != null) 'projectId': projectId,
        if (projectName != null) 'projectName': projectName,
        if (employeeId != null) 'employeeId': employeeId,
        if (employeeName != null) 'employeeName': employeeName,
        if (upworkAccountId != null) 'upworkAccountId': upworkAccountId,
        if (upworkAccountName != null) 'upworkAccountName': upworkAccountName,
        if (salespersonEmployeeId != null) 'salespersonEmployeeId': salespersonEmployeeId,
        if (salespersonName != null) 'salespersonName': salespersonName,
        if (clientName != null) 'clientName': clientName,
        'paidByUserId': paidByUserId,
        'paidByUserName': paidByUserName,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'transactionDateKey': transactionDateKey,
        'monthKey': monthKey,
        'status': status,
        'attachmentUrl': attachmentUrl,
        'attachmentStoragePath': attachmentStoragePath,
        'attachmentStatus': attachmentStatus.name,
        'description': description ?? '',
        'notes': notes ?? '',
        'lateEntry': lateEntry,
        if (lateEntryReason != null) 'lateEntryReason': lateEntryReason,
        if (originalMonthKey != null) 'originalMonthKey': originalMonthKey,
        'createdByUserId': createdByUserId,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt': null,
        'deletedByUserId': null,
      };
}
