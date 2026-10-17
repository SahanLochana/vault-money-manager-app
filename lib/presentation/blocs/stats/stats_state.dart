import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';

class CategorySpending {
  final Category category;
  final double amount;
  final double percentage;

  const CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class WalletSpending {
  final Wallet wallet;
  final double amount;
  final double percentage;

  const WalletSpending({
    required this.wallet,
    required this.amount,
    required this.percentage,
  });
}

abstract class StatsState {
  const StatsState();
}

class StatsInitial extends StatsState {
  const StatsInitial();
}

class StatsLoading extends StatsState {
  const StatsLoading();
}

class StatsLoaded extends StatsState {
  final int year;
  final int month;
  final double monthlyTotal;
  final List<CategorySpending> categoryBreakdown;
  final List<WalletSpending> walletBreakdown;
  final List<LedgerTransaction> recentExpenses;
  final List<Category> allCategories;
  final List<Wallet> allWallets;

  const StatsLoaded({
    required this.year,
    required this.month,
    required this.monthlyTotal,
    required this.categoryBreakdown,
    required this.walletBreakdown,
    required this.recentExpenses,
    required this.allCategories,
    required this.allWallets,
  });
}

class StatsError extends StatsState {
  final String message;
  const StatsError(this.message);
}
