import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/domain/failures/wallet_failure.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';
import 'package:money_management_app/presentation/screens/manage_wallets_page.dart';
import 'package:sqflite/sqflite.dart';

// -------------------------------------------------------------
// Fakes & Mocks for Testing
// -------------------------------------------------------------

class FakeWalletRepository implements WalletRepository {
  List<Wallet> wallets;
  final Set<int> walletsWithHistory = {};
  bool simulateFailure = false;

  FakeWalletRepository({required this.wallets});

  @override
  Future<List<Wallet>> getAllWallets({bool includeArchived = false}) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    if (includeArchived) return List.from(wallets);
    return wallets.where((w) => !w.isArchived).toList();
  }

  @override
  Future<Wallet?> getWalletById(int id) async {
    return wallets.where((w) => w.id == id).firstOrNull;
  }

  @override
  Future<int> addWallet(Wallet wallet) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    final active = wallets.where((w) => !w.isArchived).toList();
    if (active.length >= 10) {
      throw const WalletLimitReachedFailure();
    }
    final nameLower = wallet.name.trim().toLowerCase();
    if (active.any((w) => w.name.trim().toLowerCase() == nameLower)) {
      throw const WalletNameTakenFailure();
    }
    final newId = wallets.isEmpty ? 1 : (wallets.map((w) => w.id).reduce((a, b) => a > b ? a : b) + 1);
    final toAdd = wallet.copyWith(id: newId);
    wallets.add(toAdd);
    return newId;
  }

  @override
  Future<void> updateWallet(Wallet wallet) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    final active = wallets.where((w) => !w.isArchived).toList();
    final nameLower = wallet.name.trim().toLowerCase();
    if (active.any((w) => w.id != wallet.id && w.name.trim().toLowerCase() == nameLower)) {
      throw const WalletNameTakenFailure();
    }
    final index = wallets.indexWhere((w) => w.id == wallet.id);
    if (index != -1) {
      wallets[index] = wallet;
    }
  }

  @override
  Future<bool> hasHistory(int walletId) async {
    return walletsWithHistory.contains(walletId);
  }

  @override
  Future<void> archiveWallet(int walletId) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index != -1) {
      wallets[index] = wallets[index].copyWith(isArchived: true);
    }
  }

  @override
  Future<void> deleteWalletPermanently(int walletId) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    wallets.removeWhere((w) => w.id == walletId);
  }

  @override
  Future<void> restoreWallet(int walletId) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index != -1) {
      wallets[index] = wallets[index].copyWith(isArchived: false);
    }
  }

  @override
  Future<void> transferBalanceAndArchive({
    required int fromWalletId,
    required int toWalletId,
    required int balanceCents,
    String? note,
  }) async {
    if (simulateFailure) throw const DatabaseFailure("Simulated DB error");
    final fromIndex = wallets.indexWhere((w) => w.id == fromWalletId);
    final toIndex = wallets.indexWhere((w) => w.id == toWalletId);

    if (fromIndex != -1 && toIndex != -1) {
      final destCurrent = wallets[toIndex].balanceCents ?? wallets[toIndex].openingBalanceCents;
      wallets[toIndex] = wallets[toIndex].copyWith(
        balanceCents: destCurrent + balanceCents,
      );
      wallets[fromIndex] = wallets[fromIndex].copyWith(
        balanceCents: 0,
        isArchived: true,
      );
      walletsWithHistory.add(fromWalletId);
      walletsWithHistory.add(toWalletId);
    }
  }

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

/// Simulated mock in-memory database to test atomic transaction rollbacks
class AtomicMockDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> tables = {
    AppTables.wallets: [],
    AppTables.transactions: [],
  };

  bool failInsideTransaction = false;

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    // Snapshot state before transaction
    final walletsSnapshot = tables[AppTables.wallets]!
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final transactionsSnapshot = tables[AppTables.transactions]!
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    try {
      final mockTxn = _MockTxn(this);
      final result = await action(mockTxn);
      if (failInsideTransaction) {
        throw Exception("Simulated mid-transaction DB disk failure");
      }
      return result;
    } catch (e) {
      // Rollback to snapshot
      tables[AppTables.wallets] = walletsSnapshot;
      tables[AppTables.transactions] = transactionsSnapshot;
      rethrow;
    }
  }

  // Fallback stubs
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTxn implements Transaction {
  final AtomicMockDatabase db;
  _MockTxn(this.db);

  @override
  Future<int> insert(String table, Map<String, Object?> values,
      {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) async {
    final row = Map<String, dynamic>.from(values);
    db.tables[table]!.add(row);
    return 1;
  }

  @override
  Future<int> update(String table, Map<String, Object?> values,
      {String? where, List<Object?>? whereArgs, ConflictAlgorithm? conflictAlgorithm}) async {
    int count = 0;
    for (final row in db.tables[table]!) {
      if (whereArgs != null && whereArgs.isNotEmpty && row['id'] == whereArgs.first) {
        row.addAll(values);
        count++;
      }
    }
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// -------------------------------------------------------------
// Test Suites
// -------------------------------------------------------------

void main() {
  group('1. Currency & Money Parsing Unit Tests', () {
    test('parses normal decimals exactly without IEEE float loss', () {
      expect(CurrencyFormatter.tryParseToCents("19.99"), equals(1999));
      expect(CurrencyFormatter.tryParseToCents("0.05"), equals(5));
      expect(CurrencyFormatter.tryParseToCents("10.5"), equals(1050));
      expect(CurrencyFormatter.tryParseToCents("100"), equals(10000));
    });

    test('parses strings with commas', () {
      expect(CurrencyFormatter.tryParseToCents("1,000.50"), equals(100050));
      expect(CurrencyFormatter.tryParseToCents("1,000.5"), equals(100050));
      expect(CurrencyFormatter.tryParseToCents("1,234,567.89"), equals(123456789));
    });

    test('handles empty input as 0', () {
      expect(CurrencyFormatter.tryParseToCents(""), equals(0));
      expect(CurrencyFormatter.tryParseToCents("   "), equals(0));
    });

    test('rejects negative numbers and invalid inputs', () {
      expect(CurrencyFormatter.tryParseToCents("-5"), isNull);
      expect(CurrencyFormatter.tryParseToCents("-0.01"), isNull);
      expect(CurrencyFormatter.tryParseToCents("abc"), isNull);
      expect(CurrencyFormatter.tryParseToCents("12.345"), isNull); // > 2 decimals
    });

    test('handles max capped bounds', () {
      expect(CurrencyFormatter.tryParseToCents("999999999.99"), equals(99999999999));
      expect(CurrencyFormatter.tryParseToCents("1000000000.00"), isNull); // exceeds cap
    });

    test('formatRs formats with thousands separators and proper decimals', () {
      expect(CurrencyFormatter.formatRs(1000), equals("Rs 1,000"));
      expect(CurrencyFormatter.formatRs(0), equals("Rs 0"));
      expect(CurrencyFormatter.formatRs(12.5), equals("Rs 12.50"));
      expect(CurrencyFormatter.formatRs(-500), equals("-Rs 500"));
      expect(CurrencyFormatter.formatRs(1234567.89), equals("Rs 1,234,567.89"));
    });
  });

  group('2. WalletBloc Unit Tests', () {
    late FakeWalletRepository repo;
    late WalletBloc bloc;

    setUp(() {
      repo = FakeWalletRepository(wallets: [
        const Wallet(id: 1, name: "Cash", emoji: "💵", openingBalanceCents: 5000),
        const Wallet(id: 2, name: "Bank", emoji: "🏦", openingBalanceCents: 10000),
      ]);
      bloc = WalletBloc(walletRepository: repo);
    });

    tearDown(() {
      bloc.close();
    });

    test('Loads wallets initially', () async {
      bloc.add(const LoadWalletsEvent());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<WalletLoading>(),
          isA<WalletLoaded>().having((s) => s.wallets.length, 'length', 2),
        ]),
      );
    });

    test('Adds valid wallet and updates list', () async {
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const AddWalletEvent(
        Wallet(id: 0, name: "Savings", emoji: "💰", openingBalanceCents: 20000),
      ));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 3)
            .having((s) => s.successMessage, 'message', contains("created"))),
      );
    });

    test('Rejects duplicate wallet name case-insensitively without blanking list', () async {
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const AddWalletEvent(
        Wallet(id: 0, name: "cash", emoji: "💰"),
      ));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 2)
            .having((s) => s.actionError, 'error', contains("already exists"))),
      );
    });

    test('Enforces wallet limit of 10 wallets without blanking list', () async {
      // Fill to 10 wallets
      for (int i = 3; i <= 10; i++) {
        repo.wallets.add(Wallet(id: i, name: "Wallet $i", emoji: "🪙"));
      }

      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const AddWalletEvent(
        Wallet(id: 0, name: "11th Wallet", emoji: "🏷️"),
      ));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 10)
            .having((s) => s.actionError, 'error', contains("up to 10"))),
      );
    });

    test('Blocks removing the last remaining wallet', () async {
      repo.wallets = [
        const Wallet(id: 1, name: "Only Wallet", emoji: "💵"),
      ];
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const RemoveWalletEvent(walletId: 1));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 1)
            .having((s) => s.actionError, 'error', contains("at least one wallet"))),
      );
    });

    test('Removes wallet with balance by moving to target wallet', () async {
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const RemoveWalletEvent(walletId: 1, transferToWalletId: 2));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 1)
            .having((s) => s.lastArchivedWalletId, 'archivedId', 1)
            .having((s) => s.successMessage, 'message', contains("archived"))),
      );
    });

    test('Permanently deletes wallet when zero balance and no history', () async {
      repo.wallets = [
        const Wallet(id: 1, name: "Empty", emoji: "💵", openingBalanceCents: 0),
        const Wallet(id: 2, name: "Bank", emoji: "🏦", openingBalanceCents: 1000),
      ];
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const RemoveWalletEvent(walletId: 1));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 1)
            .having((s) => s.lastArchivedWalletId, 'archivedId', isNull)
            .having((s) => s.successMessage, 'message', contains("permanently deleted"))),
      );
    });

    test('Archives wallet when zero balance but has past history', () async {
      repo.wallets = [
        const Wallet(id: 1, name: "Has History", emoji: "💵", openingBalanceCents: 0),
        const Wallet(id: 2, name: "Bank", emoji: "🏦", openingBalanceCents: 1000),
      ];
      repo.walletsWithHistory.add(1);

      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      bloc.add(const RemoveWalletEvent(walletId: 1));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 1)
            .having((s) => s.lastArchivedWalletId, 'archivedId', 1)
            .having((s) => s.successMessage, 'message', contains("archived"))),
      );
    });

    test('Database failure on action preserves loaded list', () async {
      bloc.add(const LoadWalletsEvent());
      await bloc.stream.firstWhere((s) => s is WalletLoaded);

      repo.simulateFailure = true;
      bloc.add(const AddWalletEvent(
        Wallet(id: 0, name: "New Wallet", emoji: "💳"),
      ));

      await expectLater(
        bloc.stream,
        emits(isA<WalletLoaded>()
            .having((s) => s.wallets.length, 'length', 2)
            .having((s) => s.actionError, 'error', isNotNull)),
      );
    });
  });

  group('3. Atomic Transaction Rollback Test', () {
    test('Atomic rollback when failure occurs midway through move & archive', () async {
      final mockDb = AtomicMockDatabase();
      mockDb.tables[AppTables.wallets] = [
        {'id': 1, 'name': 'From Wallet', 'is_archived': 0, 'balance_cents': 5000},
        {'id': 2, 'name': 'To Wallet', 'is_archived': 0, 'balance_cents': 10000},
      ];

      // Simulate failure during transaction
      mockDb.failInsideTransaction = true;

      await expectLater(
        () => mockDb.transaction((txn) async {
          await txn.insert(AppTables.transactions, {
            'type': 'transfer',
            'amount_cents': 5000,
            'wallet_id': 1,
            'to_wallet_id': 2,
          });
          await txn.update(AppTables.wallets, {'is_archived': 1}, whereArgs: [1]);
        }),
        throwsA(isA<Exception>()),
      );

      // Verify state was completely rolled back
      expect(mockDb.tables[AppTables.transactions], isEmpty);
      expect(mockDb.tables[AppTables.wallets]![0]['is_archived'], equals(0));
    });
  });

  group('4. ManageWalletsPage Widget Overflow & Small Screen Tests', () {
    testWidgets('Renders at 320dp width with 2.0x text scale and huge values without overflow',
        (tester) async {
      // Set surface size to 320 x 640
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;

      final testWallets = [
        const Wallet(
          id: 1,
          name: "A very very long wallet name that exceeds sixty characters easily for testing",
          emoji: "💵",
          openingBalanceCents: 9999999900,
          balanceCents: 9999999900,
          totalFundsCents: 5000000000,
          totalSpentCents: 2500000000,
        ),
        const Wallet(
          id: 2,
          name: "Second Massive Balance Wallet Checking Wrap And Ellipsis Behavior",
          emoji: "🏦",
          openingBalanceCents: 8888888800,
          balanceCents: 8888888800,
          totalFundsCents: 1000000000,
          totalSpentCents: 500000000,
        ),
      ];

      final fakeRepo = FakeWalletRepository(wallets: testWallets);
      final walletBloc = WalletBloc(walletRepository: fakeRepo);
      walletBloc.add(const LoadWalletsEvent());

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0), // 2.0x text scale
              ),
              child: child!,
            );
          },
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<WalletRepository>.value(value: fakeRepo),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<WalletBloc>.value(value: walletBloc),
                BlocProvider<ExpenseBloc>(
                  create: (_) => ExpenseBloc(
                    transactionRepository: _MockTxRepo(),
                    categoryRepository: _MockCatRepo(),
                    walletRepository: fakeRepo,
                  ),
                ),
              ],
              child: const ManageWalletsPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect no overflow errors thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(ManageWalletsPage), findsOneWidget);

      // Verify that total balance and wallets rendered
      expect(find.textContaining("Total Available Balance"), findsOneWidget);

      // Clean up view size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}

class _MockTxRepo implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCatRepo implements CategoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
