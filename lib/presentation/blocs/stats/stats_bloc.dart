import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_event.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_state.dart';

class StatsBloc extends Bloc<StatsEvent, StatsState> {
  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;
  final WalletRepository walletRepository;
  final ExpenseRepository? expenseRepository;

  StatsBloc({
    required this.transactionRepository,
    required this.categoryRepository,
    required this.walletRepository,
    this.expenseRepository,
  }) : super(const StatsInitial()) {
    on<LoadMonthlyStatsEvent>(_onLoadMonthlyStats);
  }

  Future<void> _onLoadMonthlyStats(
    LoadMonthlyStatsEvent event,
    Emitter<StatsState> emit,
  ) async {
    emit(const StatsLoading());
    try {
      final monthlyStatsFuture =
          transactionRepository.getMonthlyStats(event.year, event.month);
      final categoriesFuture =
          categoryRepository.getAllCategoriesIncludingDeleted();
      final walletsFuture =
          walletRepository.getAllWallets(includeArchived: true);
      final monthExpensesFuture = transactionRepository.getTransactionsForMonth(
        event.year,
        event.month,
        type: 'expense',
      );

      final results = await Future.wait([
        monthlyStatsFuture,
        categoriesFuture,
        walletsFuture,
        monthExpensesFuture,
      ]);

      final stats = results[0] as MonthlyStatsResult;
      final allCategories = results[1] as List<Category>;
      final allWallets = results[2] as List<Wallet>;
      final monthExpenses = results[3] as List<LedgerTransaction>;

      final double monthlyTotal = stats.totalExpense;
      final catTotals = stats.categoryTotalsCents;
      final walletTotals = stats.walletTotals;

      final catMap = {for (final c in allCategories) c.id: c};

      // Build Category Breakdown
      final List<CategorySpending> categoryBreakdown = [];
      for (final entry in catTotals.entries) {
        final catId = entry.key;
        final amount = entry.value / 100.0;
        final percentage =
            monthlyTotal > 0 ? (amount / monthlyTotal) * 100 : 0.0;

        Category cat;
        if (catId == null) {
          cat = const Category(
            id: null,
            name: 'Uncategorized',
            emoji: '❓',
            kind: CategoryKind.expense,
          );
        } else {
          cat = catMap[catId] ??
              Category(
                id: catId,
                name: 'Deleted Category',
                emoji: '🏷️',
                kind: CategoryKind.expense,
              );
        }

        categoryBreakdown.add(CategorySpending(
          category: cat,
          amount: amount,
          percentage: percentage,
        ));
      }
      categoryBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

      // Build Wallet Breakdown
      final walletLookup = {for (final w in allWallets) w.id: w};
      final List<WalletSpending> walletBreakdown = [];
      for (final entry in walletTotals.entries) {
        final w = walletLookup[entry.key];
        if (w != null) {
          final amount = entry.value;
          final percentage =
              monthlyTotal > 0 ? (amount / monthlyTotal) * 100 : 0.0;
          walletBreakdown.add(WalletSpending(
            wallet: w,
            amount: amount,
            percentage: percentage,
          ));
        }
      }
      walletBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

      // Recent 5 expenses for the month
      final recentExpenses = monthExpenses.take(5).toList();

      emit(StatsLoaded(
        year: event.year,
        month: event.month,
        monthlyTotal: monthlyTotal,
        categoryBreakdown: categoryBreakdown,
        walletBreakdown: walletBreakdown,
        recentExpenses: recentExpenses,
        allCategories: allCategories,
        allWallets: allWallets,
      ));
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }
}
