import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';

abstract class ExpenseState {
  const ExpenseState();
}

class ExpenseInitial extends ExpenseState {
  const ExpenseInitial();
}

class ExpenseLoading extends ExpenseState {
  const ExpenseLoading();
}

class ExpenseLoaded extends ExpenseState {
  final List<LedgerTransaction> todayTransactions;
  final double todayTotal;
  final double todayIncomeTotal;
  final List<LedgerTransaction> historyTransactions;
  final Map<String, List<LedgerTransaction>> groupedTransactions;
  final List<Category> categories;
  final List<Wallet> wallets;
  final double dailyBudget;
  final bool hasMoreHistory;
  final bool isLoadingMore;
  final bool hasLedgerChanged;

  const ExpenseLoaded({
    required this.todayTransactions,
    required this.todayTotal,
    this.todayIncomeTotal = 0.0,
    required this.historyTransactions,
    required this.groupedTransactions,
    required this.categories,
    required this.wallets,
    this.dailyBudget = 500.0,
    this.hasMoreHistory = true,
    this.isLoadingMore = false,
    this.hasLedgerChanged = false,
  });

  // Backwards-compatible convenience getters:
  List<ExpenseTransaction> get todayExpenses =>
      todayTransactions.whereType<ExpenseTransaction>().toList();

  Map<String, List<ExpenseTransaction>> get groupedExpenses {
    final Map<String, List<ExpenseTransaction>> map = {};
    for (final entry in groupedTransactions.entries) {
      final expenses = entry.value.whereType<ExpenseTransaction>().toList();
      if (expenses.isNotEmpty) {
        map[entry.key] = expenses;
      }
    }
    return map;
  }

  List<TransferTransaction> get todayTransfers =>
      todayTransactions.whereType<TransferTransaction>().toList();

  Map<String, List<TransferTransaction>> get groupedTransfers {
    final Map<String, List<TransferTransaction>> map = {};
    for (final entry in groupedTransactions.entries) {
      final transfers = entry.value.whereType<TransferTransaction>().toList();
      if (transfers.isNotEmpty) {
        map[entry.key] = transfers;
      }
    }
    return map;
  }

  Category? getCategory(int? id) {
    if (id == null) return null;
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Wallet? getWallet(int id) {
    try {
      return wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  ExpenseLoaded copyWith({
    List<LedgerTransaction>? todayTransactions,
    double? todayTotal,
    double? todayIncomeTotal,
    List<LedgerTransaction>? historyTransactions,
    Map<String, List<LedgerTransaction>>? groupedTransactions,
    List<Category>? categories,
    List<Wallet>? wallets,
    double? dailyBudget,
    bool? hasMoreHistory,
    bool? isLoadingMore,
    bool? hasLedgerChanged,
  }) {
    return ExpenseLoaded(
      todayTransactions: todayTransactions ?? this.todayTransactions,
      todayTotal: todayTotal ?? this.todayTotal,
      todayIncomeTotal: todayIncomeTotal ?? this.todayIncomeTotal,
      historyTransactions: historyTransactions ?? this.historyTransactions,
      groupedTransactions: groupedTransactions ?? this.groupedTransactions,
      categories: categories ?? this.categories,
      wallets: wallets ?? this.wallets,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasLedgerChanged: hasLedgerChanged ?? false,
    );
  }
}

class ExpenseError extends ExpenseState {
  final String message;
  const ExpenseError(this.message);
}
