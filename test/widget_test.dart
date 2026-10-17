import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/expense.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/reminder_repository.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/main.dart';
import 'package:money_management_app/presentation/blocs/category/category_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/screens/add_transaction_page.dart';
import 'package:money_management_app/presentation/screens/history_page.dart';

class FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<int> addExpense(Expense expense) async => 1;
  @override
  Future<void> updateExpense(Expense expense) async {}
  @override
  Future<void> softDeleteExpense(int id) async {}
  @override
  Future<void> restoreExpense(int id) async {}
  @override
  Future<void> clearAllData() async {}
  @override
  Future<List<Map<String, dynamic>>> exportAllData() async => [];
  @override
  Future<List<Expense>> getAllExpenses() async => [];
  @override
  Future<List<Expense>> getTodayExpenses() async => [];
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async => [];
  @override
  Future<Map<String, List<Expense>>> getExpensesGroupedByDate() async => {};
  @override
  Future<Map<int, double>> getAllWalletExpenseTotals() async => {};
  @override
  Future<Map<int, double>> getMonthlyCategoryTotals(int year, int month) async => {};
  @override
  Future<Map<int, double>> getMonthlyWalletTotals(int year, int month) async => {};
  @override
  Future<double> getTodayTotal() async => 0.0;
  @override
  Future<double> getMonthlyTotal(int year, int month) async => 0.0;
}

class FakeCategoryRepository implements CategoryRepository {
  final List<Category> categories;
  FakeCategoryRepository({
    this.categories = const [
      Category(id: 1, name: 'Breakfast', emoji: '🍳', defaultAmountCents: 8000),
    ],
  });

  @override
  Future<int> addCategory(Category category) async => 1;
  @override
  Future<void> updateCategory(Category category) async {}
  @override
  Future<List<int>> deleteCategory(int id) async => [];
  @override
  Future<void> restoreCategory(int id) async {}
  @override
  Future<bool> categoryHasExpenses(int id) async => false;
  @override
  Future<int> countTransactionsForCategory(int id) async => 0;
  @override
  Future<int> countRemindersForCategory(int id) async => 0;
  @override
  Future<List<Category>> getAllCategories({String? kind}) async => categories;
  @override
  Future<List<Category>> getAllCategoriesIncludingDeleted({String? kind}) async => categories;
  @override
  Future<Category?> getCategoryById(int id) async =>
      categories.where((c) => c.id == id).firstOrNull;
}

class FakeWalletRepository implements WalletRepository {
  @override
  Future<List<Wallet>> getAllWallets({bool includeArchived = false}) async => const [
        Wallet(id: 1, name: 'In Hand', emoji: '👛', openingBalanceCents: 100000),
        Wallet(id: 2, name: 'In Bank', emoji: '🏦', openingBalanceCents: 500000),
      ];
  @override
  Future<Wallet?> getWalletById(int id) async => const Wallet(id: 1, name: 'In Hand', emoji: '👛');
  @override
  Future<int> addWallet(Wallet wallet) async => 1;
  @override
  Future<void> updateWallet(Wallet wallet) async {}
  @override
  Future<int> addFunds(WalletFund fund) async => 1;
  @override
  Future<List<WalletFund>> getFundsForWallet(int walletId) async => [];
  @override
  Future<Map<int, double>> getAllWalletFundTotals() async => {};
  @override
  Future<void> deleteFund(int id) async {}
  @override
  Future<void> restoreFund(int id) async {}
  @override
  Future<int> addTransfer(WalletTransfer transfer) async => 1;
  @override
  Future<void> softDeleteTransfer(int id) async {}
  @override
  Future<void> restoreTransfer(int id) async {}
  @override
  Future<List<WalletTransfer>> getTodayTransfers() async => [];
  @override
  Future<List<WalletTransfer>> getAllActiveTransfers() async => [];
  @override
  Future<Map<String, List<WalletTransfer>>> getTransfersGroupedByDate() async => {};
  @override
  Future<Map<int, double>> getTransferInTotals() async => {};
  @override
  Future<Map<int, double>> getTransferOutTotals() async => {};
}

class FakeReminderRepository implements ReminderRepository {
  @override
  Future<int> addReminder(ReminderSlot slot) async => 1;
  @override
  Future<void> deleteReminder(int id) async {}
  @override
  Future<List<ReminderSlot>> getAllReminders() async => [];
  @override
  Future<void> toggleReminder(int id, bool isActive) async {}
  @override
  Future<void> updateReminder(ReminderSlot slot) async {}
}

class FakeTransactionRepository implements TransactionRepository {
  @override
  Future<int> addTransaction(TransactionItem item) async => 1;
  @override
  Future<int> clearAllLedgerData() async => 0;
  @override
  Future<Map<String, dynamic>> exportAllData() async => {'schema_version': 4};
  @override
  Future<List<Map<String, dynamic>>> exportAllTransactions() async => [];
  @override
  Future<MonthlyStatsResult> getMonthlyStats(int year, int month) async {
    return MonthlyStatsResult(
      totalExpenseCents: 0,
      categoryTotalsCents: {},
      walletTotalsCents: {},
    );
  }
  @override
  Future<TransactionItem?> getTransactionById(int id) async => null;
  @override
  Future<List<TransactionItem>> getTodayTransactions({String? type}) async => [];
  @override
  Future<List<TransactionItem>> getTransactionsForMonth(int year, int month, {String? type}) async => [];
  @override
  Future<List<TransactionItem>> getPaginatedTransactions({
    int limit = 30,
    String? cursorDate,
    String? cursorTime,
    int? cursorId,
    int? walletId,
    String? type,
  }) async => [];
  @override
  Future<void> restoreTransaction(int id) async {}
  @override
  Future<void> softDeleteTransaction(int id) async {}
  @override
  Future<void> updateTransaction(TransactionItem item) async {}
}

class FakeSettingsRepository implements SettingsRepository {
  @override
  Future<double> getDailyBudget() async => 500.0;
  @override
  Future<String?> getSetting(String key) async => null;
  @override
  Future<int> getSnoozeDurationMinutes() async => 10;
  @override
  Future<bool> isWalletSetupDone() async => true;
  @override
  Future<void> setDailyBudget(double budget) async {}
  @override
  Future<void> setSetting(String key, String value) async {}
  @override
  Future<void> setSnoozeDurationMinutes(int minutes) async {}
  @override
  Future<void> setWalletSetupDone(bool done) async {}
  @override
  Future<Map<String, String>> getAllSettings() async => {};
}

void main() {
  testWidgets('App launches and renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        transactionRepository: FakeTransactionRepository(),
        expenseRepository: FakeExpenseRepository(),
        categoryRepository: FakeCategoryRepository(),
        walletRepository: FakeWalletRepository(),
        reminderRepository: FakeReminderRepository(),
        settingsRepository: FakeSettingsRepository(),
        isSetupDone: true,
        showSplash: false,
      ),
    );

    expect(find.text("Today's Spending"), findsOneWidget);
  });

  testWidgets('SplashScreen displays brand elements and navigates', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        transactionRepository: FakeTransactionRepository(),
        expenseRepository: FakeExpenseRepository(),
        categoryRepository: FakeCategoryRepository(),
        walletRepository: FakeWalletRepository(),
        reminderRepository: FakeReminderRepository(),
        settingsRepository: FakeSettingsRepository(),
        isSetupDone: true,
        showSplash: true,
      ),
    );

    expect(find.text("VAULT"), findsOneWidget);
    expect(find.text("SMART MONEY MANAGER"), findsOneWidget);

    // Let the 2-second splash timer elapse cleanly
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('AddTransactionPage prefills amount from category defaultAmountCents', (WidgetTester tester) async {
    final catRepo = FakeCategoryRepository(
      categories: const [
        Category(id: 1, name: 'Breakfast', emoji: '🍳', defaultAmountCents: 8000),
      ],
    );
    final walletRepo = FakeWalletRepository();
    final txRepo = FakeTransactionRepository();
    final expenseRepo = FakeExpenseRepository();
    final settingsRepo = FakeSettingsRepository();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CategoryRepository>.value(value: catRepo),
          RepositoryProvider<WalletRepository>.value(value: walletRepo),
          RepositoryProvider<TransactionRepository>.value(value: txRepo),
          RepositoryProvider<ExpenseRepository>.value(value: expenseRepo),
          RepositoryProvider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<CategoryBloc>(
              create: (_) => CategoryBloc(categoryRepository: catRepo),
            ),
            BlocProvider<WalletBloc>(
              create: (_) => WalletBloc(walletRepository: walletRepo),
            ),
            BlocProvider<ExpenseBloc>(
              create: (_) => ExpenseBloc(
                transactionRepository: txRepo,
                categoryRepository: catRepo,
                walletRepository: walletRepo,
                settingsRepository: settingsRepo,
              ),
            ),
          ],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Breakfast chip is present
    expect(find.text('Breakfast'), findsOneWidget);

    // Tap Breakfast chip
    await tester.tap(find.text('Breakfast'));
    await tester.pumpAndSettle();

    // Verify amount is prefilled with 80 (from 8000 cents)
    expect(find.text('80'), findsOneWidget);
  });

  testWidgets('AddTransactionPage supports zero categories with Uncategorized', (WidgetTester tester) async {
    final catRepo = FakeCategoryRepository(categories: const []);
    final walletRepo = FakeWalletRepository();
    final txRepo = FakeTransactionRepository();
    final expenseRepo = FakeExpenseRepository();
    final settingsRepo = FakeSettingsRepository();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CategoryRepository>.value(value: catRepo),
          RepositoryProvider<WalletRepository>.value(value: walletRepo),
          RepositoryProvider<TransactionRepository>.value(value: txRepo),
          RepositoryProvider<ExpenseRepository>.value(value: expenseRepo),
          RepositoryProvider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<CategoryBloc>(
              create: (_) => CategoryBloc(categoryRepository: catRepo),
            ),
            BlocProvider<WalletBloc>(
              create: (_) => WalletBloc(walletRepository: walletRepo),
            ),
            BlocProvider<ExpenseBloc>(
              create: (_) => ExpenseBloc(
                transactionRepository: txRepo,
                categoryRepository: catRepo,
                walletRepository: walletRepo,
                settingsRepository: settingsRepo,
              ),
            ),
          ],
          child: const MaterialApp(
            home: AddTransactionPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // With zero categories, Uncategorized is visible and selectable
    expect(find.text('Uncategorized'), findsOneWidget);
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
  });

  testWidgets('HistoryPage renders cleanly with empty state', (WidgetTester tester) async {
    final catRepo = FakeCategoryRepository();
    final walletRepo = FakeWalletRepository();
    final txRepo = FakeTransactionRepository();
    final expenseRepo = FakeExpenseRepository();
    final settingsRepo = FakeSettingsRepository();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CategoryRepository>.value(value: catRepo),
          RepositoryProvider<WalletRepository>.value(value: walletRepo),
          RepositoryProvider<TransactionRepository>.value(value: txRepo),
          RepositoryProvider<ExpenseRepository>.value(value: expenseRepo),
          RepositoryProvider<SettingsRepository>.value(value: settingsRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ExpenseBloc>(
              create: (_) => ExpenseBloc(
                transactionRepository: txRepo,
                categoryRepository: catRepo,
                walletRepository: walletRepo,
                settingsRepository: settingsRepo,
              ),
            ),
          ],
          child: const MaterialApp(
            home: HistoryPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('No transaction history'), findsOneWidget);
  });
}
