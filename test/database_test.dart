import 'package:flutter_test/flutter_test.dart';
import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/data/datasources/category_local_datasource.dart';
import 'package:money_management_app/data/datasources/reminder_local_datasource.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/data/datasources/wallet_local_datasource.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:sqflite/sqflite.dart';

/// In-memory table store simulating SQLite operations for unit tests
class InMemoryTestDatabase implements Database, Transaction {
  final Map<String, List<Map<String, dynamic>>> tables = {
    AppTables.wallets: [],
    AppTables.categories: [],
    AppTables.transactions: [],
    AppTables.reminderSlots: [],
    AppTables.appSettings: [],
  };

  int _autoId = 1;

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final row = Map<String, dynamic>.from(values);
    if (!row.containsKey('id') || row['id'] == null) {
      row['id'] = _autoId++;
    }
    tables[table]!.add(row);
    return row['id'] as int;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    int count = 0;
    final list = tables[table]!;
    for (int i = 0; i < list.length; i++) {
      bool matches = true;
      if (where != null && whereArgs != null) {
        if (where.contains('id = ?')) {
          matches = list[i]['id'] == whereArgs.first;
        }
      }
      if (matches) {
        list[i].addAll(values);
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = tables[table]!;
    if (where == null) {
      final count = list.length;
      list.clear();
      return count;
    }
    int count = 0;
    list.removeWhere((row) {
      if (where.contains('category_id = ?') && whereArgs != null) {
        final matches = row['category_id'] == whereArgs.first;
        if (matches) count++;
        return matches;
      }
      if (where.contains('id = ?') && whereArgs != null) {
        final matches = row['id'] == whereArgs.first;
        if (matches) count++;
        return matches;
      }
      return false;
    });
    return count;
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final list = tables[table]!;
    final filtered = list.where((row) {
      if (where != null) {
        if (where.contains('deleted_at IS NULL') && row['deleted_at'] != null) {
          return false;
        }
        if (where.contains('kind = ?') && whereArgs != null) {
          if (row['kind'] != whereArgs.first) return false;
        }
        if (where.contains('id = ?') && whereArgs != null) {
          if (row['id'] != whereArgs.first) return false;
        }
      }
      return true;
    }).toList();

    if (limit != null && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    // 1. Single-query wallet balances simulation:
    // Calculates opening_balance_cents + income + transfers_in - expenses - transfers_out
    if (sql.contains('balance_cents') && sql.contains(AppTables.wallets)) {
      final wallets = tables[AppTables.wallets]!;
      final transactions = tables[AppTables.transactions]!;

      return wallets.map((w) {
        final wId = w['id'] as int;
        final opening = (w['opening_balance_cents'] as int?) ?? 0;

        int net = opening;
        for (final t in transactions) {
          if (t['deleted_at'] != null) continue; // Soft-deleted ignored
          final type = t['type'] as String;
          final amount = t['amount_cents'] as int;
          final walletId = t['wallet_id'] as int;
          final toWalletId = t['to_wallet_id'] as int?;

          if (type == 'income' && walletId == wId) {
            net += amount;
          } else if (type == 'transfer' && toWalletId == wId) {
            net += amount;
          } else if (type == 'expense' && walletId == wId) {
            net -= amount;
          } else if (type == 'transfer' && walletId == wId) {
            net -= amount;
          }
        }

        return {
          ...w,
          'balance_cents': net,
        };
      }).toList();
    }

    // 2. Monthly Total Simulation
    if (sql.contains('COALESCE(SUM(amount_cents), 0) AS total_cents') ||
        (sql.contains('COALESCE(SUM(amount_cents), 0) as total'))) {
      final txs = tables[AppTables.transactions]!;
      int sum = 0;
      final start = arguments?[0] as String?;
      final end = arguments?[1] as String?;

      for (final t in txs) {
        if (t['deleted_at'] != null) continue;
        if (t['type'] != 'expense') continue;
        final date = t['occurred_date'] as String;
        if (start != null && date.compareTo(start) < 0) continue;
        if (end != null && date.compareTo(end) >= 0) continue;
        sum += (t['amount_cents'] as int);
      }
      return [
        {'total_cents': sum, 'total': sum}
      ];
    }

    // 3. Category Breakdown Simulation
    if (sql.contains('category_id') && sql.contains('UNION ALL')) {
      final cats = tables[AppTables.categories]!;
      final txs = tables[AppTables.transactions]!;
      final start = arguments?[0] as String?;
      final end = arguments?[1] as String?;

      final results = <Map<String, dynamic>>[];
      for (final c in cats) {
        if (c['kind'] != 'expense') continue;
        final catId = c['id'] as int;
        int sum = 0;
        for (final t in txs) {
          if (t['deleted_at'] != null) continue;
          if (t['type'] != 'expense') continue;
          if (t['category_id'] != catId) continue;
          final date = t['occurred_date'] as String;
          if (start != null && date.compareTo(start) < 0) continue;
          if (end != null && date.compareTo(end) >= 0) continue;
          sum += (t['amount_cents'] as int);
        }
        if (c['deleted_at'] == null || sum > 0) {
          results.add({
            'category_id': catId,
            'category_name': c['name'],
            'total_cents': sum,
          });
        }
      }

      // Check uncategorized
      int uncatSum = 0;
      for (final t in txs) {
        if (t['deleted_at'] != null) continue;
        if (t['type'] != 'expense') continue;
        if (t['category_id'] != null) continue;
        final date = t['occurred_date'] as String;
        if (start != null && date.compareTo(start) < 0) continue;
        if (end != null && date.compareTo(end) >= 0) continue;
        uncatSum += (t['amount_cents'] as int);
      }
      if (uncatSum > 0) {
        results.add({
          'category_id': null,
          'category_name': 'Uncategorized',
          'total_cents': uncatSum,
        });
      }

      return results;
    }

    // 4. Wallet Breakdown Simulation
    if (sql.contains('wallet_id') && sql.contains('total_cents')) {
      final wallets = tables[AppTables.wallets]!;
      final txs = tables[AppTables.transactions]!;
      final start = arguments?[0] as String?;
      final end = arguments?[1] as String?;

      final results = <Map<String, dynamic>>[];
      for (final w in wallets) {
        final wId = w['id'] as int;
        int sum = 0;
        for (final t in txs) {
          if (t['deleted_at'] != null) continue;
          if (t['type'] != 'expense') continue;
          if (t['wallet_id'] != wId) continue;
          final date = t['occurred_date'] as String;
          if (start != null && date.compareTo(start) < 0) continue;
          if (end != null && date.compareTo(end) >= 0) continue;
          sum += (t['amount_cents'] as int);
        }
        results.add({
          'wallet_id': wId,
          'wallet_name': w['name'],
          'total_cents': sum,
        });
      }
      return results;
    }

    // 5. Keyset pagination / raw query fallback
    if (sql.contains('FROM transactions')) {
      final txs = tables[AppTables.transactions]!;
      var filtered = txs.where((t) => t['deleted_at'] == null).toList();

      // Sort by occurred_date DESC, occurred_time DESC, id DESC
      filtered.sort((a, b) {
        final cmpDate = (b['occurred_date'] as String).compareTo(a['occurred_date'] as String);
        if (cmpDate != 0) return cmpDate;
        final cmpTime = (b['occurred_time'] as String).compareTo(a['occurred_time'] as String);
        if (cmpTime != 0) return cmpTime;
        return (b['id'] as int).compareTo(a['id'] as int);
      });

      // Cursor filtering if provided
      if (arguments != null && arguments.length >= 6) {
        final cDate = arguments[0] as String?;
        final cTime = arguments[2] as String?;
        final cId = arguments[5] as int?;

        if (cDate != null && cTime != null && cId != null) {
          filtered = filtered.where((t) {
            final tDate = t['occurred_date'] as String;
            final tTime = t['occurred_time'] as String;
            final tId = t['id'] as int;

            if (tDate.compareTo(cDate) < 0) return true;
            if (tDate == cDate && tTime.compareTo(cTime) < 0) return true;
            if (tDate == cDate && tTime == cTime && tId < cId) return true;
            return false;
          }).toList();
        }
      }

      final limit = arguments?.last is int ? arguments!.last as int : 30;
      return filtered.take(limit).toList();
    }

    return [];
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    // For unit testing, invoke the transaction directly
    return await action(this as dynamic);
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryTestDatabase testDb;
  late AppDatabase appDb;
  late WalletLocalDatasource walletDatasource;
  late CategoryLocalDatasource categoryDatasource;
  late TransactionLocalDatasource transactionDatasource;
  late ReminderLocalDatasource reminderDatasource;

  setUp(() {
    testDb = InMemoryTestDatabase();
    appDb = AppDatabase.withDatabase(testDb);
    walletDatasource = WalletLocalDatasource(appDatabase: appDb);
    categoryDatasource = CategoryLocalDatasource(appDatabase: appDb);
    transactionDatasource = TransactionLocalDatasource(appDatabase: appDb);
    reminderDatasource = ReminderLocalDatasource(appDatabase: appDb);
  });

  group('Database Architecture & Target Schema Tests', () {
    test('1. Single SQL query calculates accurate wallet balances', () async {
      // Seed wallets with opening balances
      await walletDatasource.insertWallet(const Wallet(
        id: 1,
        name: 'In Hand',
        emoji: '👛',
        openingBalanceCents: 50000, // 500.00
      ));
      await walletDatasource.insertWallet(const Wallet(
        id: 2,
        name: 'In Bank',
        emoji: '🏦',
        openingBalanceCents: 100000, // 1000.00
      ));

      // 1. Income into In Hand: +200.00 (20000 cents)
      await transactionDatasource.insertTransaction(const IncomeTransaction(
        amountCents: 20000,
        walletId: 1,
        occurredDate: '2026-10-15',
        occurredTime: '10:00',
        createdAt: '2026-10-15T10:00:00',
        updatedAt: '2026-10-15T10:00:00',
      ));

      // 2. Expense from In Hand: -150.00 (15000 cents)
      await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 15000,
        walletId: 1,
        categoryId: 1,
        occurredDate: '2026-10-15',
        occurredTime: '11:00',
        createdAt: '2026-10-15T11:00:00',
        updatedAt: '2026-10-15T11:00:00',
      ));

      // 3. Transfer from In Bank (2) to In Hand (1): 300.00 (30000 cents)
      await transactionDatasource.insertTransaction(const TransferTransaction(
        amountCents: 30000,
        walletId: 2,
        toWalletId: 1,
        occurredDate: '2026-10-15',
        occurredTime: '12:00',
        createdAt: '2026-10-15T12:00:00',
        updatedAt: '2026-10-15T12:00:00',
      ));

      // 4. Soft-deleted expense (should NOT affect balance): 50.00
      final deletedTxId = await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 5000,
        walletId: 1,
        categoryId: 1,
        occurredDate: '2026-10-15',
        occurredTime: '13:00',
        createdAt: '2026-10-15T13:00:00',
        updatedAt: '2026-10-15T13:00:00',
      ));
      await transactionDatasource.softDeleteTransaction(deletedTxId);

      // Verify single query balances:
      // In Hand: 50000 + 20000 (income) - 15000 (expense) + 30000 (transfer in) = 85000 cents (Rs 850.00)
      // In Bank: 100000 - 30000 (transfer out) = 70000 cents (Rs 700.00)
      final wallets = await walletDatasource.getAllWallets();
      expect(wallets.length, 2);

      final inHand = wallets.firstWhere((w) => w.id == 1);
      final inBank = wallets.firstWhere((w) => w.id == 2);

      expect(inHand.balanceCents, 85000);
      expect(inHand.balance, 850.00);

      expect(inBank.balanceCents, 70000);
      expect(inBank.balance, 700.00);
    });

    test('2. Month range calculation accurately replaces LIKE YYYY-MM%', () {
      final (febStart, febEnd) = TransactionLocalDatasource.getMonthRange(2026, 2);
      expect(febStart, '2026-02-01');
      expect(febEnd, '2026-03-01');

      final (decStart, decEnd) = TransactionLocalDatasource.getMonthRange(2026, 12);
      expect(decStart, '2026-12-01');
      expect(decEnd, '2027-01-01');
    });

    test('3. Monthly stats with category breakdown (active + deleted with spending + uncategorized)', () async {
      // Setup categories
      await categoryDatasource.insertCategory(const Category(
        id: 1,
        name: 'Breakfast',
        emoji: '🍳',
      ));
      await categoryDatasource.insertCategory(const Category(
        id: 2,
        name: 'Lunch',
        emoji: '🍔',
      ));
      await categoryDatasource.insertCategory(const Category(
        id: 3,
        name: 'Old Service',
        emoji: '📦',
        deletedAt: '2026-10-01T00:00:00', // Deleted category
      ));

      // Setup wallets
      await walletDatasource.insertWallet(const Wallet(id: 1, name: 'In Hand', emoji: '👛'));

      // Transactions in October 2026
      await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 8000, // Breakfast: 80.00
        walletId: 1,
        categoryId: 1,
        occurredDate: '2026-10-05',
        occurredTime: '08:30',
        createdAt: '2026-10-05T08:30:00',
        updatedAt: '2026-10-05T08:30:00',
      ));

      await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 5000, // Old Service (deleted): 50.00
        walletId: 1,
        categoryId: 3,
        occurredDate: '2026-10-10',
        occurredTime: '14:00',
        createdAt: '2026-10-10T14:00:00',
        updatedAt: '2026-10-10T14:00:00',
      ));

      await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 3000, // Uncategorized: 30.00
        walletId: 1,
        categoryId: null,
        occurredDate: '2026-10-12',
        occurredTime: '16:00',
        createdAt: '2026-10-12T16:00:00',
        updatedAt: '2026-10-12T16:00:00',
      ));

      // Query monthly stats for October 2026
      final stats = await transactionDatasource.getMonthlyStats(2026, 10);

      // Total expense: 8000 + 5000 + 3000 = 16000 cents (Rs 160.00)
      expect(stats.totalExpenseCents, 16000);

      // Category breakdown
      expect(stats.categoryTotalsCents[1], 8000); // Breakfast
      expect(stats.categoryTotalsCents[2], 0); // Lunch (active, 0 spending)
      expect(stats.categoryTotalsCents[3], 5000); // Old Service (deleted, but has spending)
      expect(stats.categoryTotalsCents[null], 3000); // Uncategorized

      // Wallet breakdown
      expect(stats.walletTotalsCents[1], 16000);
    });

    test('4. Keyset pagination on (occurred_date, occurred_time, id)', () async {
      // Insert multiple transactions
      for (int i = 1; i <= 5; i++) {
        await transactionDatasource.insertTransaction(ExpenseTransaction(
          id: i,
          amountCents: i * 1000,
          walletId: 1,
          occurredDate: '2026-10-0$i',
          occurredTime: '10:00',
          createdAt: '2026-10-0${i}T10:00:00',
          updatedAt: '2026-10-0${i}T10:00:00',
        ));
      }

      // Page 1: limit 2
      final page1 = await transactionDatasource.getPaginatedTransactions(limit: 2);
      expect(page1.length, 2);
      expect(page1[0].id, 5); // 2026-10-05
      expect(page1[1].id, 4); // 2026-10-04

      // Page 2: keyset cursor from last item of page 1
      final cursor = page1.last;
      final page2 = await transactionDatasource.getPaginatedTransactions(
        limit: 2,
        cursorDate: cursor.occurredDate,
        cursorTime: cursor.occurredTime,
        cursorId: cursor.id,
      );
      expect(page2.length, 2);
      expect(page2[0].id, 3); // 2026-10-03
      expect(page2[1].id, 2); // 2026-10-02
    });

    test('5. Category delete soft-deletes category, deletes reminders, and NEVER rewrites transactions', () async {
      // Create category
      final catId = await categoryDatasource.insertCategory(const Category(
        name: 'Subscriptions',
        emoji: '💳',
      ));

      // Create reminder slot linked to this category
      final reminderId = await reminderDatasource.insertReminder(ReminderSlot(
        categoryId: catId,
        time: '09:00',
      ));

      // Create an expense linked to this category
      final txId = await transactionDatasource.insertTransaction(ExpenseTransaction(
        amountCents: 2500,
        walletId: 1,
        categoryId: catId,
        occurredDate: '2026-10-17',
        occurredTime: '09:30',
        createdAt: '2026-10-17T09:30:00',
        updatedAt: '2026-10-17T09:30:00',
      ));

      // Delete the category
      await categoryDatasource.deleteCategory(catId);

      // Verify category is soft-deleted
      final activeCategories = await categoryDatasource.getAllCategories();
      expect(activeCategories.any((c) => c.id == catId), isFalse);

      final deletedCat = await categoryDatasource.getCategoryById(catId);
      expect(deletedCat?.deletedAt, isNotNull);

      // Verify reminder slot was removed
      final reminder = await reminderDatasource.getReminderById(reminderId);
      expect(reminder, isNull);

      // Verify historical transaction was NOT rewritten or deleted!
      final tx = await transactionDatasource.getTransactionById(txId);
      expect(tx, isNotNull);
      expect(tx?.categoryId, catId); // Preserved original category ID
      expect(tx?.isDeleted, isFalse);
    });

    test('6. Clear All Data wipes ledger in single transaction and restores opening balances', () async {
      // Setup wallet with opening balance
      await walletDatasource.insertWallet(const Wallet(
        id: 1,
        name: 'In Hand',
        emoji: '👛',
        openingBalanceCents: 45000, // Rs 450.00
      ));

      // Add expense and income
      await transactionDatasource.insertTransaction(const IncomeTransaction(
        amountCents: 20000,
        walletId: 1,
        occurredDate: '2026-10-17',
        occurredTime: '10:00',
        createdAt: '2026-10-17T10:00:00',
        updatedAt: '2026-10-17T10:00:00',
      ));
      await transactionDatasource.insertTransaction(const ExpenseTransaction(
        amountCents: 15000,
        walletId: 1,
        categoryId: 1,
        occurredDate: '2026-10-17',
        occurredTime: '11:00',
        createdAt: '2026-10-17T11:00:00',
        updatedAt: '2026-10-17T11:00:00',
      ));

      // Balances before clear: 45000 + 20000 - 15000 = 50000
      var wallets = await walletDatasource.getAllWallets();
      expect(wallets.first.balanceCents, 50000);

      // Clear all ledger data
      await transactionDatasource.clearAllLedgerData();

      // Verify all ledger rows are deleted
      final transactions = testDb.tables[AppTables.transactions]!;
      expect(transactions.isEmpty, isTrue);

      // Verify wallet opening balance is preserved and balance == opening balance
      wallets = await walletDatasource.getAllWallets();
      expect(wallets.first.openingBalanceCents, 45000);
      expect(wallets.first.balanceCents, 45000);
      expect(wallets.first.balance, 450.00);
    });

    test('7. ReminderSlot fallback to category default_amount_cents when NULL', () {
      const categoryDefaultCents = 12000; // 120.00

      // Case A: reminder defaultAmountCents is null -> fallback to category
      const slotWithFallback = ReminderSlot(
        id: 1,
        categoryId: 1,
        time: '08:00',
        defaultAmountCents: null,
      );
      expect(slotWithFallback.effectiveAmountCents(categoryDefaultCents), 12000);

      // Case B: reminder has explicit defaultAmountCents -> use explicit
      const slotWithCustom = ReminderSlot(
        id: 2,
        categoryId: 1,
        time: '08:00',
        defaultAmountCents: 9500,
      );
      expect(slotWithCustom.effectiveAmountCents(categoryDefaultCents), 9500);
    });

    test('8. Inserting wallets with id: 0 assigns unique autoincremented IDs without collision', () async {
      // Form dialog creates wallets with id: 0
      final id1 = await walletDatasource.insertWallet(const Wallet(
        id: 0,
        name: 'First New Wallet',
        emoji: '💵',
        openingBalanceCents: 1000,
      ));
      final id2 = await walletDatasource.insertWallet(const Wallet(
        id: 0,
        name: 'Second New Wallet',
        emoji: '💳',
        openingBalanceCents: 2000,
      ));

      expect(id1, isPositive);
      expect(id2, isPositive);
      expect(id1, isNot(equals(id2)));

      final all = await walletDatasource.getAllWallets();
      final w1 = all.firstWhere((w) => w.id == id1);
      final w2 = all.firstWhere((w) => w.id == id2);
      expect(w1.name, 'First New Wallet');
      expect(w2.name, 'Second New Wallet');
    });
  });
}
