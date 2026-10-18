import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_state.dart';

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;
  final WalletRepository walletRepository;
  final SettingsRepository? settingsRepository;
  final ExpenseRepository? expenseRepository;

  ExpenseBloc({
    required this.transactionRepository,
    required this.categoryRepository,
    required this.walletRepository,
    this.settingsRepository,
    this.expenseRepository,
  }) : super(const ExpenseInitial()) {
    on<LoadExpenses>(_onLoadExpenses);
    on<LoadTodayExpenses>(_onLoadTodayExpenses);
    on<LoadMoreExpenses>(_onLoadMoreExpenses);
    on<AddExpenseEvent>(_onAddExpense);
    on<UpdateExpenseEvent>(_onUpdateExpense);
    on<DeleteExpenseEvent>(_onDeleteExpense);
    on<RestoreExpenseEvent>(_onRestoreExpense);
    on<ClearAllExpensesEvent>(_onClearAllExpenses);
  }

  static const int _pageSize = 30;

  Map<String, List<LedgerTransaction>> _groupByDate(List<LedgerTransaction> list) {
    final Map<String, List<LedgerTransaction>> map = {};
    for (final item in list) {
      map.putIfAbsent(item.occurredDate, () => []).add(item);
    }
    return map;
  }

  Future<void> _onLoadExpenses(LoadExpenses event, Emitter<ExpenseState> emit) async {
    emit(const ExpenseLoading());
    try {
      final todayFuture = transactionRepository.getTodayTransactions();
      final historyFuture = transactionRepository.getPaginatedTransactions(limit: _pageSize);
      final categoriesFuture = categoryRepository.getAllCategoriesIncludingDeleted();
      final walletsFuture = walletRepository.getAllWallets(includeArchived: true);
      final budgetFuture = settingsRepository?.getDailyBudget() ?? Future.value(500.0);

      final results = await Future.wait([
        todayFuture,
        historyFuture,
        categoriesFuture,
        walletsFuture,
        budgetFuture,
      ]);

      final todayTransactions = results[0] as List<LedgerTransaction>;
      final historyTransactions = results[1] as List<LedgerTransaction>;
      final categories = results[2] as List<Category>;
      final wallets = results[3] as List<Wallet>;
      final dailyBudget = results[4] as double;

      double todayExpenseTotal = 0;
      double todayIncomeTotal = 0;
      for (final tx in todayTransactions) {
        if (tx.isExpense) {
          todayExpenseTotal += tx.amount;
        } else if (tx.isIncome) {
          todayIncomeTotal += tx.amount;
        }
      }

      emit(ExpenseLoaded(
        todayTransactions: todayTransactions,
        todayTotal: todayExpenseTotal,
        todayIncomeTotal: todayIncomeTotal,
        historyTransactions: historyTransactions,
        groupedTransactions: _groupByDate(historyTransactions),
        categories: categories,
        wallets: wallets,
        dailyBudget: dailyBudget,
        hasMoreHistory: historyTransactions.length >= _pageSize,
        isLoadingMore: false,
        hasLedgerChanged: false,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onLoadTodayExpenses(LoadTodayExpenses event, Emitter<ExpenseState> emit) async {
    if (state is! ExpenseLoaded) {
      add(const LoadExpenses());
      return;
    }
    final current = state as ExpenseLoaded;
    try {
      final todayTransactions = await transactionRepository.getTodayTransactions();
      double todayExpenseTotal = 0;
      double todayIncomeTotal = 0;
      for (final tx in todayTransactions) {
        if (tx.isExpense) {
          todayExpenseTotal += tx.amount;
        } else if (tx.isIncome) {
          todayIncomeTotal += tx.amount;
        }
      }

      emit(current.copyWith(
        todayTransactions: todayTransactions,
        todayTotal: todayExpenseTotal,
        todayIncomeTotal: todayIncomeTotal,
        hasLedgerChanged: false,
      ));
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onLoadMoreExpenses(LoadMoreExpenses event, Emitter<ExpenseState> emit) async {
    if (state is! ExpenseLoaded) return;
    final current = state as ExpenseLoaded;
    if (!current.hasMoreHistory || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    try {
      final lastTx = current.historyTransactions.isNotEmpty
          ? current.historyTransactions.last
          : null;

      final moreTransactions = await transactionRepository.getPaginatedTransactions(
        limit: _pageSize,
        cursorDate: lastTx?.occurredDate,
        cursorTime: lastTx?.occurredTime,
        cursorId: lastTx?.id,
      );

      final combined = [...current.historyTransactions, ...moreTransactions];

      emit(current.copyWith(
        historyTransactions: combined,
        groupedTransactions: _groupByDate(combined),
        isLoadingMore: false,
        hasMoreHistory: moreTransactions.length >= _pageSize,
        hasLedgerChanged: false,
      ));
    } catch (e) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onAddExpense(AddExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await transactionRepository.addTransaction(event.expense);
      await _refreshWithLedgerChanged(emit);
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onUpdateExpense(UpdateExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await transactionRepository.updateTransaction(event.expense);
      await _refreshWithLedgerChanged(emit);
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onDeleteExpense(DeleteExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await transactionRepository.softDeleteTransaction(event.id);
      await _refreshWithLedgerChanged(emit);
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onRestoreExpense(RestoreExpenseEvent event, Emitter<ExpenseState> emit) async {
    try {
      await transactionRepository.restoreTransaction(event.id);
      await _refreshWithLedgerChanged(emit);
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _onClearAllExpenses(ClearAllExpensesEvent event, Emitter<ExpenseState> emit) async {
    try {
      await transactionRepository.clearAllLedgerData();
      await _refreshWithLedgerChanged(emit);
    } catch (e) {
      emit(ExpenseError(e.toString()));
    }
  }

  Future<void> _refreshWithLedgerChanged(Emitter<ExpenseState> emit) async {
    final todayFuture = transactionRepository.getTodayTransactions();
    final historyFuture = transactionRepository.getPaginatedTransactions(limit: _pageSize);
    final categoriesFuture = categoryRepository.getAllCategoriesIncludingDeleted();
    final walletsFuture = walletRepository.getAllWallets();
    final budgetFuture = settingsRepository?.getDailyBudget() ?? Future.value(500.0);

    final results = await Future.wait([
      todayFuture,
      historyFuture,
      categoriesFuture,
      walletsFuture,
      budgetFuture,
    ]);

    final todayTransactions = results[0] as List<LedgerTransaction>;
    final historyTransactions = results[1] as List<LedgerTransaction>;
    final categories = results[2] as List<Category>;
    final wallets = results[3] as List<Wallet>;
    final dailyBudget = results[4] as double;

    double todayExpenseTotal = 0;
    double todayIncomeTotal = 0;
    for (final tx in todayTransactions) {
      if (tx.isExpense) {
        todayExpenseTotal += tx.amount;
      } else if (tx.isIncome) {
        todayIncomeTotal += tx.amount;
      }
    }

    emit(ExpenseLoaded(
      todayTransactions: todayTransactions,
      todayTotal: todayExpenseTotal,
      todayIncomeTotal: todayIncomeTotal,
      historyTransactions: historyTransactions,
      groupedTransactions: _groupByDate(historyTransactions),
      categories: categories,
      wallets: wallets,
      dailyBudget: dailyBudget,
      hasMoreHistory: historyTransactions.length >= _pageSize,
      isLoadingMore: false,
      hasLedgerChanged: true,
    ));
  }
}
