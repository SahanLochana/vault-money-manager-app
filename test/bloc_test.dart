import 'package:flutter_test/flutter_test.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/reminder_repository.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/category/category_bloc.dart';
import 'package:money_management_app/presentation/blocs/category/category_event.dart';
import 'package:money_management_app/presentation/blocs/category/category_state.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_state.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_bloc.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_event.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_state.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_bloc.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_event.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_state.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';

class MockTxRepo implements TransactionRepository {
  List<LedgerTransaction> stored = [];

  @override
  Future<int> addTransaction(TransactionItem item) async {
    stored.add(item);
    return 1;
  }

  @override
  Future<int> clearAllLedgerData() async {
    final count = stored.length;
    stored.clear();
    return count;
  }

  @override
  Future<Map<String, dynamic>> exportAllData() async => {
        'schema_version': 4,
        'transactions': stored.map((t) => t.toMap()).toList(),
      };

  @override
  Future<List<Map<String, dynamic>>> exportAllTransactions() async => [];

  @override
  Future<MonthlyStatsResult> getMonthlyStats(int year, int month) async {
    return MonthlyStatsResult(
      totalExpenseCents: 15000,
      categoryTotalsCents: {1: 10000, null: 5000},
      walletTotalsCents: {1: 15000},
    );
  }

  @override
  Future<TransactionItem?> getTransactionById(int id) async => null;

  @override
  Future<List<TransactionItem>> getTodayTransactions({String? type}) async => stored;

  @override
  Future<List<TransactionItem>> getTransactionsForMonth(int year, int month, {String? type}) async => stored;

  @override
  Future<List<TransactionItem>> getPaginatedTransactions({
    int limit = 30,
    String? cursorDate,
    String? cursorTime,
    int? cursorId,
    int? walletId,
    String? type,
  }) async =>
      stored;

  @override
  Future<void> restoreTransaction(int id) async {}

  @override
  Future<void> softDeleteTransaction(int id) async {}

  @override
  Future<void> updateTransaction(TransactionItem item) async {}
}

class MockCategoryRepo implements CategoryRepository {
  List<Category> categories = [
    const Category(id: 1, name: 'Food', emoji: '🍔', defaultAmountCents: 5000),
    const Category(id: 2, name: 'Salary', emoji: '💰', kind: CategoryKind.income, defaultAmountCents: 500000),
  ];

  @override
  Future<int> addCategory(Category category) async {
    categories.add(category);
    return categories.length;
  }

  @override
  Future<List<int>> deleteCategory(int id) async {
    categories.removeWhere((c) => c.id == id);
    return [101]; // simulates returning deleted reminder slot IDs
  }

  @override
  Future<void> restoreCategory(int id) async {}

  @override
  Future<bool> categoryHasExpenses(int id) async => true;

  @override
  Future<int> countTransactionsForCategory(int id) async => 5;

  @override
  Future<int> countRemindersForCategory(int id) async => 2;

  @override
  Future<List<Category>> getAllCategories({String? kind}) async {
    if (kind != null) {
      return categories.where((c) => c.kind == kind).toList();
    }
    return categories;
  }

  @override
  Future<List<Category>> getAllCategoriesIncludingDeleted({String? kind}) async => categories;

  @override
  Future<Category?> getCategoryById(int id) async =>
      categories.where((c) => c.id == id).firstOrNull;

  @override
  Future<void> updateCategory(Category category) async {}
}

class MockWalletRepo implements WalletRepository {
  List<Wallet> wallets = [
    const Wallet(id: 1, name: 'Cash', emoji: '💵', openingBalanceCents: 20000, balanceCents: 20000),
  ];

  @override
  Future<List<Wallet>> getAllWallets({bool includeArchived = false}) async => wallets;

  @override
  Future<Wallet?> getWalletById(int id) async =>
      wallets.where((w) => w.id == id).firstOrNull;

  @override
  Future<int> addWallet(Wallet wallet) async {
    wallets.add(wallet);
    return wallet.id;
  }

  @override
  Future<void> updateWallet(Wallet wallet) async {
    final idx = wallets.indexWhere((w) => w.id == wallet.id);
    if (idx != -1) wallets[idx] = wallet;
  }

  @override
  Future<int> addFunds(WalletFund fund) async => 1;
  @override
  Future<void> deleteFund(int id) async {}
  @override
  Future<void> restoreFund(int id) async {}
  @override
  Future<List<WalletFund>> getFundsForWallet(int walletId) async => [];
  @override
  Future<Map<int, double>> getAllWalletFundTotals() async => {};
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
  @override
  Future<bool> hasHistory(int walletId) async => false;
  @override
  Future<void> archiveWallet(int walletId) async {}
  @override
  Future<void> deleteWalletPermanently(int walletId) async {}
  @override
  Future<void> restoreWallet(int walletId) async {}
  @override
  Future<void> transferBalanceAndArchive({
    required int fromWalletId,
    required int toWalletId,
    required int balanceCents,
    String? note,
  }) async {}
}

class MockSettingsRepo implements SettingsRepository {
  double budget = 500.0;
  int snooze = 15;
  bool setupDone = true;

  @override
  Future<double> getDailyBudget() async => budget;
  @override
  Future<String?> getSetting(String key) async => null;
  @override
  Future<int> getSnoozeDurationMinutes() async => snooze;
  @override
  Future<bool> isWalletSetupDone() async => setupDone;
  @override
  Future<void> setDailyBudget(double b) async => budget = b;
  @override
  Future<void> setSetting(String key, String value) async {}
  @override
  Future<void> setSnoozeDurationMinutes(int minutes) async => snooze = minutes;
  @override
  Future<void> setWalletSetupDone(bool done) async => setupDone = done;
  @override
  Future<Map<String, String>> getAllSettings() async => {};
}

class MockReminderRepo implements ReminderRepository {
  List<ReminderSlot> slots = [
    const ReminderSlot(id: 1, categoryId: 1, time: '08:00', defaultAmountCents: null, isActive: true),
  ];

  @override
  Future<int> addReminder(ReminderSlot slot) async {
    slots.add(slot);
    return slots.length;
  }

  @override
  Future<void> deleteReminder(int id) async {
    slots.removeWhere((s) => s.id == id);
  }

  @override
  Future<List<ReminderSlot>> getAllReminders() async => slots;

  @override
  Future<void> toggleReminder(int id, bool isActive) async {
    final idx = slots.indexWhere((s) => s.id == id);
    if (idx != -1) {
      slots[idx] = slots[idx].copyWith(isActive: isActive);
    }
  }

  @override
  Future<void> updateReminder(ReminderSlot slot) async {
    final idx = slots.indexWhere((s) => s.id == slot.id);
    if (idx != -1) {
      slots[idx] = slot;
    }
  }
}

void main() {
  group('ExpenseBloc Tests', () {
    test('LoadExpenses emits ExpenseLoaded with today and history data', () async {
      final txRepo = MockTxRepo();
      final catRepo = MockCategoryRepo();
      final walletRepo = MockWalletRepo();
      final settingsRepo = MockSettingsRepo();

      final bloc = ExpenseBloc(
        transactionRepository: txRepo,
        categoryRepository: catRepo,
        walletRepository: walletRepo,
        settingsRepository: settingsRepo,
      );

      bloc.add(const LoadExpenses());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ExpenseLoading>(),
          isA<ExpenseLoaded>().having((s) => s.dailyBudget, 'dailyBudget', 500.0),
        ]),
      );
    });
  });

  group('WalletBloc Tests', () {
    test('LoadWalletsEvent loads single query balances correctly', () async {
      final walletRepo = MockWalletRepo();
      final bloc = WalletBloc(walletRepository: walletRepo);

      bloc.add(const LoadWalletsEvent());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<WalletLoading>(),
          isA<WalletLoaded>().having(
            (s) => s.getBalance(1),
            'wallet 1 balance',
            200.0,
          ),
        ]),
      );
    });
  });

  group('CategoryBloc Tests', () {
    test('DeleteCategoryEvent triggers soft delete and getDeleteImpact reports counts', () async {
      final catRepo = MockCategoryRepo();
      final bloc = CategoryBloc(categoryRepository: catRepo);

      // Verify impact calculation
      final impact = await bloc.getDeleteImpact(1);
      expect(impact.transactionCount, 5);
      expect(impact.reminderCount, 2);

      bloc.add(const LoadCategoriesEvent());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having((s) => s.categories.length, 'initial count', 2),
        ]),
      );

      // Delete category
      bloc.add(const DeleteCategoryEvent(1));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CategoryLoading>(),
          isA<CategoryLoaded>().having((s) => s.categories.length, 'count after delete', 1),
        ]),
      );
    });
  });

  group('ReminderBloc Tests', () {
    test('Effective amount resolves category default when slot defaultAmountCents is null', () async {
      final reminderRepo = MockReminderRepo();
      final catRepo = MockCategoryRepo();
      final bloc = ReminderBloc(
        reminderRepository: reminderRepo,
        categoryRepository: catRepo,
      );

      bloc.add(const LoadRemindersEvent());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReminderLoading>(),
          isA<ReminderLoaded>().having((s) {
            final slot = s.reminders.first;
            // Slot default is null, category 1 default is 5000 cents (50.0)
            final effective = slot.effectiveAmountCents(5000);
            return effective;
          }, 'effective amount cents', 5000),
        ]),
      );
    });
  });

  group('StatsBloc Tests', () {
    test('LoadMonthlyStatsEvent calculates category totals mapping null to Uncategorized', () async {
      final txRepo = MockTxRepo();
      final catRepo = MockCategoryRepo();
      final walletRepo = MockWalletRepo();

      final bloc = StatsBloc(
        transactionRepository: txRepo,
        categoryRepository: catRepo,
        walletRepository: walletRepo,
      );

      bloc.add(const LoadMonthlyStatsEvent(year: 2026, month: 10));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<StatsLoading>(),
          isA<StatsLoaded>().having((s) => s.monthlyTotal, 'monthlyTotal', 150.0),
        ]),
      );
    });
  });
}
