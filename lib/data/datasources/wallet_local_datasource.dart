import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:sqflite/sqflite.dart';

class WalletLocalDatasource {
  final AppDatabase appDatabase;

  WalletLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  /// Fetches all active wallets and calculates current balances in ONE single query.
  /// Balance formula: opening_balance_cents + income + transfers_in - expenses - transfers_out
  Future<List<Wallet>> getAllWallets({bool includeArchived = false}) async {
    final db = await _db;
    final whereClause = includeArchived ? '' : 'WHERE w.${AppTables.colWalletIsArchived} = 0';

    final results = await db.rawQuery('''
      SELECT 
        w.${AppTables.colWalletId},
        w.${AppTables.colWalletName},
        w.${AppTables.colWalletEmoji},
        w.${AppTables.colWalletOpeningBalanceCents},
        w.${AppTables.colWalletSortOrder},
        w.${AppTables.colWalletIsArchived},
        w.${AppTables.colWalletCreatedAt},
        (
          w.${AppTables.colWalletOpeningBalanceCents} +
          COALESCE(SUM(CASE 
            WHEN t.${AppTables.colTxType} = 'income' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'transfer' AND t.${AppTables.colTxToWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'expense' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN -t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'transfer' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN -t.${AppTables.colTxAmountCents}
            ELSE 0
          END), 0)
        ) AS balance_cents,
        COALESCE(SUM(CASE 
          WHEN t.${AppTables.colTxType} = 'income' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
          ELSE 0
        END), 0) AS total_funds_cents,
        COALESCE(SUM(CASE 
          WHEN t.${AppTables.colTxType} = 'expense' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
          ELSE 0
        END), 0) AS total_spent_cents
      FROM ${AppTables.wallets} w
      LEFT JOIN ${AppTables.transactions} t 
        ON (t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} OR t.${AppTables.colTxToWalletId} = w.${AppTables.colWalletId})
        AND t.${AppTables.colTxDeletedAt} IS NULL
      $whereClause
      GROUP BY w.${AppTables.colWalletId}
      ORDER BY w.${AppTables.colWalletSortOrder} ASC, w.${AppTables.colWalletId} ASC
    ''');

    return results.map((e) => Wallet.fromMap(e)).toList();
  }

  Future<Wallet?> getWalletById(int id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        w.${AppTables.colWalletId},
        w.${AppTables.colWalletName},
        w.${AppTables.colWalletEmoji},
        w.${AppTables.colWalletOpeningBalanceCents},
        w.${AppTables.colWalletSortOrder},
        w.${AppTables.colWalletIsArchived},
        w.${AppTables.colWalletCreatedAt},
        (
          w.${AppTables.colWalletOpeningBalanceCents} +
          COALESCE(SUM(CASE 
            WHEN t.${AppTables.colTxType} = 'income' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'transfer' AND t.${AppTables.colTxToWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'expense' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN -t.${AppTables.colTxAmountCents}
            WHEN t.${AppTables.colTxType} = 'transfer' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN -t.${AppTables.colTxAmountCents}
            ELSE 0
          END), 0)
        ) AS balance_cents,
        COALESCE(SUM(CASE 
          WHEN t.${AppTables.colTxType} = 'income' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
          ELSE 0
        END), 0) AS total_funds_cents,
        COALESCE(SUM(CASE 
          WHEN t.${AppTables.colTxType} = 'expense' AND t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} THEN t.${AppTables.colTxAmountCents}
          ELSE 0
        END), 0) AS total_spent_cents
      FROM ${AppTables.wallets} w
      LEFT JOIN ${AppTables.transactions} t 
        ON (t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId} OR t.${AppTables.colTxToWalletId} = w.${AppTables.colWalletId})
        AND t.${AppTables.colTxDeletedAt} IS NULL
      WHERE w.${AppTables.colWalletId} = ?
      GROUP BY w.${AppTables.colWalletId}
    ''', [id]);

    if (results.isEmpty) return null;
    return Wallet.fromMap(results.first);
  }

  Future<int> insertWallet(Wallet wallet) async {
    final db = await _db;
    return await db.insert(AppTables.wallets, wallet.toMap());
  }

  Future<int> updateWallet(Wallet wallet) async {
    final db = await _db;
    return await db.update(
      AppTables.wallets,
      wallet.toMap(),
      where: '${AppTables.colWalletId} = ?',
      whereArgs: [wallet.id],
    );
  }

  Future<int> archiveWallet(int id) async {
    final db = await _db;
    return await db.update(
      AppTables.wallets,
      {AppTables.colWalletIsArchived: 1},
      where: '${AppTables.colWalletId} = ?',
      whereArgs: [id],
    );
  }

  // --- Compatibility methods mapping to unified transactions table ---

  Future<int> insertWalletFund(Map<String, dynamic> fundMap) async {
    final db = await _db;
    final now = DateTime.now();
    final dateStr = now.toIso8601String().substring(0, 10);
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return await db.insert(AppTables.transactions, {
      AppTables.colTxType: 'income',
      AppTables.colTxAmountCents: fundMap[AppTables.colFundAmountCents],
      AppTables.colTxWalletId: fundMap[AppTables.colFundWalletId],
      AppTables.colTxToWalletId: null,
      AppTables.colTxCategoryId: null,
      AppTables.colTxOccurredDate: dateStr,
      AppTables.colTxOccurredTime: timeStr,
      AppTables.colTxNote: fundMap[AppTables.colFundNote],
      AppTables.colTxDeletedAt: null,
      AppTables.colTxCreatedAt: fundMap[AppTables.colFundCreatedAt] ?? now.toIso8601String(),
      AppTables.colTxUpdatedAt: now.toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getFundsForWallet(int walletId) async {
    final db = await _db;
    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxWalletId} = ? AND ${AppTables.colTxType} = ? AND ${AppTables.colTxDeletedAt} IS NULL',
      whereArgs: [walletId, 'income'],
      orderBy: '${AppTables.colTxCreatedAt} DESC',
    );
    return maps.map((row) => {
      AppTables.colFundId: row[AppTables.colTxId],
      AppTables.colFundWalletId: row[AppTables.colTxWalletId],
      AppTables.colFundAmountCents: row[AppTables.colTxAmountCents],
      AppTables.colFundNote: row[AppTables.colTxNote],
      AppTables.colFundCreatedAt: row[AppTables.colTxCreatedAt],
    }).toList();
  }

  Future<Map<int, int>> getAllWalletFundTotalsCents() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT ${AppTables.colTxWalletId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxType} = 'income' AND ${AppTables.colTxDeletedAt} IS NULL
      GROUP BY ${AppTables.colTxWalletId}
    ''');

    final Map<int, int> totals = {};
    for (final row in results) {
      final walletId = row[AppTables.colTxWalletId] as int;
      final total = (row['total'] as int?) ?? 0;
      totals[walletId] = total;
    }
    return totals;
  }

  Future<int> deleteWalletFund(int id) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: DateTime.now().toIso8601String(),
        AppTables.colTxUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'income'],
    );
  }

  Future<int> restoreWalletFund(int id) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: null,
        AppTables.colTxUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'income'],
    );
  }

  Future<int> insertWalletTransfer(Map<String, dynamic> transferMap) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.insert(AppTables.transactions, {
      AppTables.colTxType: 'transfer',
      AppTables.colTxAmountCents: transferMap[AppTables.colTransferAmountCents],
      AppTables.colTxWalletId: transferMap[AppTables.colTransferFromWalletId],
      AppTables.colTxToWalletId: transferMap[AppTables.colTransferToWalletId],
      AppTables.colTxCategoryId: null,
      AppTables.colTxOccurredDate: transferMap[AppTables.colTransferDate],
      AppTables.colTxOccurredTime: transferMap[AppTables.colTransferTime],
      AppTables.colTxNote: transferMap[AppTables.colTransferNote],
      AppTables.colTxDeletedAt: null,
      AppTables.colTxCreatedAt: transferMap[AppTables.colTransferCreatedAt] ?? now,
      AppTables.colTxUpdatedAt: now,
    });
  }

  Future<int> softDeleteTransfer(int id) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: DateTime.now().toIso8601String(),
        AppTables.colTxUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'transfer'],
    );
  }

  Future<int> restoreTransfer(int id) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: null,
        AppTables.colTxUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'transfer'],
    );
  }

  Future<List<Map<String, dynamic>>> getTodayTransfers(String todayStr) async {
    final db = await _db;
    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxType} = ? AND ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxOccurredDate} = ?',
      whereArgs: ['transfer', todayStr],
      orderBy: '${AppTables.colTxOccurredTime} DESC, ${AppTables.colTxCreatedAt} DESC',
    );
    return maps.map((row) => {
      AppTables.colTransferId: row[AppTables.colTxId],
      AppTables.colTransferFromWalletId: row[AppTables.colTxWalletId],
      AppTables.colTransferToWalletId: row[AppTables.colTxToWalletId],
      AppTables.colTransferAmountCents: row[AppTables.colTxAmountCents],
      AppTables.colTransferDate: row[AppTables.colTxOccurredDate],
      AppTables.colTransferTime: row[AppTables.colTxOccurredTime],
      AppTables.colTransferNote: row[AppTables.colTxNote],
      AppTables.colTransferIsDeleted: 0,
      AppTables.colTransferCreatedAt: row[AppTables.colTxCreatedAt],
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllActiveTransfers() async {
    final db = await _db;
    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxType} = ? AND ${AppTables.colTxDeletedAt} IS NULL',
      whereArgs: ['transfer'],
      orderBy: '${AppTables.colTxOccurredDate} DESC, ${AppTables.colTxOccurredTime} DESC, ${AppTables.colTxCreatedAt} DESC',
    );
    return maps.map((row) => {
      AppTables.colTransferId: row[AppTables.colTxId],
      AppTables.colTransferFromWalletId: row[AppTables.colTxWalletId],
      AppTables.colTransferToWalletId: row[AppTables.colTxToWalletId],
      AppTables.colTransferAmountCents: row[AppTables.colTxAmountCents],
      AppTables.colTransferDate: row[AppTables.colTxOccurredDate],
      AppTables.colTransferTime: row[AppTables.colTxOccurredTime],
      AppTables.colTransferNote: row[AppTables.colTxNote],
      AppTables.colTransferIsDeleted: 0,
      AppTables.colTransferCreatedAt: row[AppTables.colTxCreatedAt],
    }).toList();
  }

  Future<Map<int, int>> getTransferInTotalsCents() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT ${AppTables.colTxToWalletId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxType} = 'transfer' AND ${AppTables.colTxDeletedAt} IS NULL
      GROUP BY ${AppTables.colTxToWalletId}
    ''');

    final Map<int, int> totals = {};
    for (final row in results) {
      final walletId = row[AppTables.colTxToWalletId] as int;
      final total = (row['total'] as int?) ?? 0;
      totals[walletId] = total;
    }
    return totals;
  }

  Future<Map<int, int>> getTransferOutTotalsCents() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT ${AppTables.colTxWalletId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxType} = 'transfer' AND ${AppTables.colTxDeletedAt} IS NULL
      GROUP BY ${AppTables.colTxWalletId}
    ''');

    final Map<int, int> totals = {};
    for (final row in results) {
      final walletId = row[AppTables.colTxWalletId] as int;
      final total = (row['total'] as int?) ?? 0;
      totals[walletId] = total;
    }
    return totals;
  }
}
