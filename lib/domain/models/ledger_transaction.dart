import 'package:money_management_app/data/database/tables.dart';

/// Sealed hierarchy representing all ledger movements in the unified transactions table.
sealed class LedgerTransaction {
  final int? id;
  final int amountCents;
  final int walletId;
  final String occurredDate; // YYYY-MM-DD
  final String occurredTime; // HH:mm
  final String? note;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  // Joined display attributes (from wallets)
  final String? walletName;
  final String? walletEmoji;

  const LedgerTransaction({
    this.id,
    required this.amountCents,
    required this.walletId,
    required this.occurredDate,
    required this.occurredTime,
    this.note,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.walletName,
    this.walletEmoji,
  });

  String get type;
  int? get categoryId => null;
  int? get toWalletId => null;
  String? get categoryName => null;
  String? get categoryEmoji => null;
  String? get toWalletName => null;
  String? get toWalletEmoji => null;

  double get amount => amountCents / 100.0;
  String get formattedAmount => 'Rs ${amount.toStringAsFixed(0)}';
  bool get isDeleted => deletedAt != null;
  String get date => occurredDate;
  String get time => occurredTime;

  bool get isExpense => this is ExpenseTransaction;
  bool get isIncome => this is IncomeTransaction;
  bool get isTransfer => this is TransferTransaction;

  factory LedgerTransaction.create({
    int? id,
    required String type,
    required int amountCents,
    required int walletId,
    int? toWalletId,
    int? categoryId,
    required String occurredDate,
    required String occurredTime,
    String? note,
    String? deletedAt,
    required String createdAt,
    required String updatedAt,
    String? walletName,
    String? walletEmoji,
    String? categoryName,
    String? categoryEmoji,
    String? toWalletName,
    String? toWalletEmoji,
  }) {
    switch (type) {
      case 'expense':
        return ExpenseTransaction(
          id: id,
          amountCents: amountCents,
          walletId: walletId,
          categoryId: categoryId,
          occurredDate: occurredDate,
          occurredTime: occurredTime,
          note: note,
          deletedAt: deletedAt,
          createdAt: createdAt,
          updatedAt: updatedAt,
          walletName: walletName,
          walletEmoji: walletEmoji,
          categoryName: categoryName,
          categoryEmoji: categoryEmoji,
        );
      case 'income':
        return IncomeTransaction(
          id: id,
          amountCents: amountCents,
          walletId: walletId,
          categoryId: categoryId,
          occurredDate: occurredDate,
          occurredTime: occurredTime,
          note: note,
          deletedAt: deletedAt,
          createdAt: createdAt,
          updatedAt: updatedAt,
          walletName: walletName,
          walletEmoji: walletEmoji,
          categoryName: categoryName,
          categoryEmoji: categoryEmoji,
        );
      case 'transfer':
        return TransferTransaction(
          id: id,
          amountCents: amountCents,
          walletId: walletId,
          toWalletId: toWalletId ?? walletId,
          occurredDate: occurredDate,
          occurredTime: occurredTime,
          note: note,
          deletedAt: deletedAt,
          createdAt: createdAt,
          updatedAt: updatedAt,
          walletName: walletName,
          walletEmoji: walletEmoji,
          toWalletName: toWalletName,
          toWalletEmoji: toWalletEmoji,
        );
      default:
        throw ArgumentError('Unknown transaction type: $type');
    }
  }

  Map<String, dynamic> toMap();

  factory LedgerTransaction.fromMap(Map<String, dynamic> map) {
    final type = map[AppTables.colTxType] as String;
    switch (type) {
      case 'expense':
        return ExpenseTransaction.fromMap(map);
      case 'income':
        return IncomeTransaction.fromMap(map);
      case 'transfer':
        return TransferTransaction.fromMap(map);
      default:
        throw ArgumentError('Unknown transaction type: $type');
    }
  }
}

/// Expense transaction: money leaving a wallet, optionally assigned to an expense category.
class ExpenseTransaction extends LedgerTransaction {
  @override
  final int? categoryId;
  @override
  final String? categoryName;
  @override
  final String? categoryEmoji;

  const ExpenseTransaction({
    super.id,
    required super.amountCents,
    required super.walletId,
    this.categoryId,
    required super.occurredDate,
    required super.occurredTime,
    super.note,
    super.deletedAt,
    required super.createdAt,
    required super.updatedAt,
    super.walletName,
    super.walletEmoji,
    this.categoryName,
    this.categoryEmoji,
  });

  @override
  String get type => 'expense';

  ExpenseTransaction copyWith({
    int? id,
    int? amountCents,
    int? walletId,
    int? categoryId,
    String? occurredDate,
    String? occurredTime,
    String? note,
    String? deletedAt,
    String? createdAt,
    String? updatedAt,
    String? walletName,
    String? walletEmoji,
    String? categoryName,
    String? categoryEmoji,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      occurredDate: occurredDate ?? this.occurredDate,
      occurredTime: occurredTime ?? this.occurredTime,
      note: note ?? this.note,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      walletName: walletName ?? this.walletName,
      walletEmoji: walletEmoji ?? this.walletEmoji,
      categoryName: categoryName ?? this.categoryName,
      categoryEmoji: categoryEmoji ?? this.categoryEmoji,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppTables.colTxId: id,
      AppTables.colTxType: type,
      AppTables.colTxAmountCents: amountCents,
      AppTables.colTxWalletId: walletId,
      AppTables.colTxToWalletId: null,
      AppTables.colTxCategoryId: categoryId,
      AppTables.colTxOccurredDate: occurredDate,
      AppTables.colTxOccurredTime: occurredTime,
      AppTables.colTxNote: note,
      AppTables.colTxDeletedAt: deletedAt,
      AppTables.colTxCreatedAt: createdAt,
      AppTables.colTxUpdatedAt: updatedAt,
    };
  }

  factory ExpenseTransaction.fromMap(Map<String, dynamic> map) {
    return ExpenseTransaction(
      id: map[AppTables.colTxId] as int?,
      amountCents: map[AppTables.colTxAmountCents] as int,
      walletId: map[AppTables.colTxWalletId] as int,
      categoryId: map[AppTables.colTxCategoryId] as int?,
      occurredDate: map[AppTables.colTxOccurredDate] as String,
      occurredTime: map[AppTables.colTxOccurredTime] as String,
      note: map[AppTables.colTxNote] as String?,
      deletedAt: map[AppTables.colTxDeletedAt] as String?,
      createdAt: map[AppTables.colTxCreatedAt] as String,
      updatedAt: map[AppTables.colTxUpdatedAt] as String,
      walletName: map['wallet_name'] as String?,
      walletEmoji: map['wallet_emoji'] as String?,
      categoryName: map['category_name'] as String?,
      categoryEmoji: map['category_emoji'] as String?,
    );
  }
}

/// Income transaction: money entering a wallet, optionally assigned to an income category.
class IncomeTransaction extends LedgerTransaction {
  @override
  final int? categoryId;
  @override
  final String? categoryName;
  @override
  final String? categoryEmoji;

  const IncomeTransaction({
    super.id,
    required super.amountCents,
    required super.walletId,
    this.categoryId,
    required super.occurredDate,
    required super.occurredTime,
    super.note,
    super.deletedAt,
    required super.createdAt,
    required super.updatedAt,
    super.walletName,
    super.walletEmoji,
    this.categoryName,
    this.categoryEmoji,
  });

  @override
  String get type => 'income';

  IncomeTransaction copyWith({
    int? id,
    int? amountCents,
    int? walletId,
    int? categoryId,
    String? occurredDate,
    String? occurredTime,
    String? note,
    String? deletedAt,
    String? createdAt,
    String? updatedAt,
    String? walletName,
    String? walletEmoji,
    String? categoryName,
    String? categoryEmoji,
  }) {
    return IncomeTransaction(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      occurredDate: occurredDate ?? this.occurredDate,
      occurredTime: occurredTime ?? this.occurredTime,
      note: note ?? this.note,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      walletName: walletName ?? this.walletName,
      walletEmoji: walletEmoji ?? this.walletEmoji,
      categoryName: categoryName ?? this.categoryName,
      categoryEmoji: categoryEmoji ?? this.categoryEmoji,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppTables.colTxId: id,
      AppTables.colTxType: type,
      AppTables.colTxAmountCents: amountCents,
      AppTables.colTxWalletId: walletId,
      AppTables.colTxToWalletId: null,
      AppTables.colTxCategoryId: categoryId,
      AppTables.colTxOccurredDate: occurredDate,
      AppTables.colTxOccurredTime: occurredTime,
      AppTables.colTxNote: note,
      AppTables.colTxDeletedAt: deletedAt,
      AppTables.colTxCreatedAt: createdAt,
      AppTables.colTxUpdatedAt: updatedAt,
    };
  }

  factory IncomeTransaction.fromMap(Map<String, dynamic> map) {
    return IncomeTransaction(
      id: map[AppTables.colTxId] as int?,
      amountCents: map[AppTables.colTxAmountCents] as int,
      walletId: map[AppTables.colTxWalletId] as int,
      categoryId: map[AppTables.colTxCategoryId] as int?,
      occurredDate: map[AppTables.colTxOccurredDate] as String,
      occurredTime: map[AppTables.colTxOccurredTime] as String,
      note: map[AppTables.colTxNote] as String?,
      deletedAt: map[AppTables.colTxDeletedAt] as String?,
      createdAt: map[AppTables.colTxCreatedAt] as String,
      updatedAt: map[AppTables.colTxUpdatedAt] as String,
      walletName: map['wallet_name'] as String?,
      walletEmoji: map['wallet_emoji'] as String?,
      categoryName: map['category_name'] as String?,
      categoryEmoji: map['category_emoji'] as String?,
    );
  }
}

/// Transfer transaction: money moving from one wallet to another.
class TransferTransaction extends LedgerTransaction {
  @override
  final int toWalletId;
  @override
  final String? toWalletName;
  @override
  final String? toWalletEmoji;

  const TransferTransaction({
    super.id,
    required super.amountCents,
    required super.walletId,
    required this.toWalletId,
    required super.occurredDate,
    required super.occurredTime,
    super.note,
    super.deletedAt,
    required super.createdAt,
    required super.updatedAt,
    super.walletName,
    super.walletEmoji,
    this.toWalletName,
    this.toWalletEmoji,
  });

  int get fromWalletId => walletId;
  String? get fromWalletName => walletName;
  String? get fromWalletEmoji => walletEmoji;

  @override
  String get type => 'transfer';

  TransferTransaction copyWith({
    int? id,
    int? amountCents,
    int? fromWalletId,
    int? toWalletId,
    String? occurredDate,
    String? occurredTime,
    String? note,
    String? deletedAt,
    String? createdAt,
    String? updatedAt,
    String? walletName,
    String? walletEmoji,
    String? toWalletName,
    String? toWalletEmoji,
  }) {
    return TransferTransaction(
      id: id ?? this.id,
      amountCents: amountCents ?? this.amountCents,
      walletId: fromWalletId ?? walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      occurredDate: occurredDate ?? this.occurredDate,
      occurredTime: occurredTime ?? this.occurredTime,
      note: note ?? this.note,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      walletName: walletName ?? this.walletName,
      walletEmoji: walletEmoji ?? this.walletEmoji,
      toWalletName: toWalletName ?? this.toWalletName,
      toWalletEmoji: toWalletEmoji ?? this.toWalletEmoji,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppTables.colTxId: id,
      AppTables.colTxType: type,
      AppTables.colTxAmountCents: amountCents,
      AppTables.colTxWalletId: walletId,
      AppTables.colTxToWalletId: toWalletId,
      AppTables.colTxCategoryId: null,
      AppTables.colTxOccurredDate: occurredDate,
      AppTables.colTxOccurredTime: occurredTime,
      AppTables.colTxNote: note,
      AppTables.colTxDeletedAt: deletedAt,
      AppTables.colTxCreatedAt: createdAt,
      AppTables.colTxUpdatedAt: updatedAt,
    };
  }

  factory TransferTransaction.fromMap(Map<String, dynamic> map) {
    return TransferTransaction(
      id: map[AppTables.colTxId] as int?,
      amountCents: map[AppTables.colTxAmountCents] as int,
      walletId: map[AppTables.colTxWalletId] as int,
      toWalletId: map[AppTables.colTxToWalletId] as int,
      occurredDate: map[AppTables.colTxOccurredDate] as String,
      occurredTime: map[AppTables.colTxOccurredTime] as String,
      note: map[AppTables.colTxNote] as String?,
      deletedAt: map[AppTables.colTxDeletedAt] as String?,
      createdAt: map[AppTables.colTxCreatedAt] as String,
      updatedAt: map[AppTables.colTxUpdatedAt] as String,
      walletName: map['wallet_name'] as String?,
      walletEmoji: map['wallet_emoji'] as String?,
      toWalletName: map['to_wallet_name'] as String?,
      toWalletEmoji: map['to_wallet_emoji'] as String?,
    );
  }
}

// Backward-compatible typedef
typedef TransactionItem = LedgerTransaction;
