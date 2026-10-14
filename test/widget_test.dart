import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_management_app/presentation/screens/settings_page.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/expense.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/reminder_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/main.dart';

class FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<int> addExpense(Expense expense) async => 1;
  @override
  Future<void> clearAllData() async {}
  @override
  Future<List<Map<String, dynamic>>> exportAllData() async => [];
  @override
  Future<List<Expense>> getAllExpenses() async => [];
  @override
  Future<Map<String, List<Expense>>> getExpensesGroupedByDate() async => {};
  @override
  Future<List<Expense>> getExpensesForMonth(int year, int month) async => [];
  @override
  Future<Map<int, double>> getMonthlyCategoryTotals(int year, int month) async => {};
  @override
  Future<double> getMonthlyTotal(int year, int month) async => 0.0;
  @override
  Future<Map<int, double>> getMonthlyWalletTotals(int year, int month) async => {};
  @override
  Future<Map<int, double>> getAllWalletExpenseTotals() async => {};
  @override
  Future<List<Expense>> getTodayExpenses() async => [];
  @override
  Future<double> getTodayTotal() async => 0.0;
  @override
  Future<void> restoreExpense(int id) async {}
  @override
  Future<void> softDeleteExpense(int id) async {}
  @override
  Future<void> updateExpense(Expense expense) async {}
}

class FakeCategoryRepository implements CategoryRepository {
  @override
  Future<int> addCategory(Category category) async => 1;
  @override
  Future<bool> categoryHasExpenses(int id) async => false;
  @override
  Future<void> deleteCategory(int id) async {}
  @override
  Future<List<Category>> getAllCategories() async => const [
        Category(id: 1, name: 'Breakfast', emoji: '🍳', defaultAmountCents: 8000, isSystem: true),
      ];
  @override
  Future<Category?> getCategoryById(int id) async => const Category(
        id: 1,
        name: 'Breakfast',
        emoji: '🍳',
        defaultAmountCents: 8000,
        isSystem: true,
      );
}

class FakeWalletRepository implements WalletRepository {
  @override
  Future<List<Wallet>> getAllWallets() async => const [
        Wallet(id: 1, name: 'In Hand', emoji: '👛'),
        Wallet(id: 2, name: 'In Bank', emoji: '🏦'),
      ];
  @override
  Future<Wallet?> getWalletById(int id) async => const Wallet(id: 1, name: 'In Hand', emoji: '👛');
  @override
  Future<int> addFunds(WalletFund fund) async => 1;
  @override
  Future<List<WalletFund>> getFundsForWallet(int walletId) async => [];
  @override
  Future<Map<int, double>> getAllWalletFundTotals() async => {};
  @override
  Future<void> deleteFund(int id) async {}
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

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        expenseRepository: FakeExpenseRepository(),
        categoryRepository: FakeCategoryRepository(),
        walletRepository: FakeWalletRepository(),
        reminderRepository: FakeReminderRepository(),
        isSetupDone: true,
        showSplash: false,
      ),
    );

    expect(find.text("Today's Spending"), findsOneWidget);
  });

  testWidgets('SplashScreen displays brand elements', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        expenseRepository: FakeExpenseRepository(),
        categoryRepository: FakeCategoryRepository(),
        walletRepository: FakeWalletRepository(),
        reminderRepository: FakeReminderRepository(),
        isSetupDone: true,
        showSplash: true,
      ),
    );

    expect(find.text("VAULT"), findsOneWidget);
    expect(find.text("SMART MONEY MANAGER"), findsOneWidget);
  });

  testWidgets('SettingsPage displays Snooze Duration setting tile and opens dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Snooze Duration"), findsOneWidget);
    expect(find.text("1 hour"), findsOneWidget);

    await tester.tap(find.text("Snooze Duration"));
    await tester.pumpAndSettle();

    expect(find.text("15 minutes"), findsOneWidget);
    expect(find.text("30 minutes"), findsOneWidget);
    expect(find.text("2 hours"), findsOneWidget);
  });
}
