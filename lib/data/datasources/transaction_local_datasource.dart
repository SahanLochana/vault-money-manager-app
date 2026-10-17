import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';
import 'package:sqflite/sqflite.dart';

class MonthlyStatsResult {
  final int totalExpenseCents;
  final Map<int?, int> categoryTotalsCents; // key: category_id (null for Uncategorized)
  final Map<int, int> walletTotalsCents; // key: wallet_id

  MonthlyStatsResult({
    required this.totalExpenseCents,
    required this.categoryTotalsCents,
    required this.walletTotalsCents,
  });

  double get totalExpense => totalExpenseCents / 100.0;
  Map<int, double> get walletTotals =>
      walletTotalsCents.map((k, v) => MapEntry(k, v / 100.0));
  Map<int?, double> get categoryTotals =>
      categoryTotalsCents.map((k, v) => MapEntry(k, v / 100.0));
}

class TransactionLocalDatasource {
  final AppDatabase appDatabase;

  TransactionLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  // --- Helper to calculate ISO month range [startDate, endDate) ---
  static (String, String) getMonthRange(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);

    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-01';
    final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-01';

    return (startStr, endStr);
  }

  Future<int> insertTransaction(TransactionItem item) async {
    final db = await _db;
    return await db.insert(AppTables.transactions, item.toMap());
  }

  Future<int> updateTransaction(TransactionItem item) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      item.toMap(),
      where: '${AppTables.colTxId} = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> softDeleteTransaction(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: now,
        AppTables.colTxUpdatedAt: now,
      },
      where: '${AppTables.colTxId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreTransaction(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: null,
        AppTables.colTxUpdatedAt: now,
      },
      where: '${AppTables.colTxId} = ?',
      whereArgs: [id],
    );
  }

  Future<TransactionItem?> getTransactionById(int id) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        t.*,
        c.${AppTables.colCatName} AS category_name,
        c.${AppTables.colCatEmoji} AS category_emoji,
        w.${AppTables.colWalletName} AS wallet_name,
        w.${AppTables.colWalletEmoji} AS wallet_emoji,
        tw.${AppTables.colWalletName} AS to_wallet_name,
        tw.${AppTables.colWalletEmoji} AS to_wallet_emoji
      FROM ${AppTables.transactions} t
      LEFT JOIN ${AppTables.categories} c ON c.${AppTables.colCatId} = t.${AppTables.colTxCategoryId}
      LEFT JOIN ${AppTables.wallets} w ON w.${AppTables.colWalletId} = t.${AppTables.colTxWalletId}
      LEFT JOIN ${AppTables.wallets} tw ON tw.${AppTables.colWalletId} = t.${AppTables.colTxToWalletId}
      WHERE t.${AppTables.colTxId} = ?
    ''', [id]);

    if (results.isEmpty) return null;
    return TransactionItem.fromMap(results.first);
  }

  Future<List<TransactionItem>> getTodayTransactions({String? type}) async {
    final db = await _db;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final where = <String>[
      't.${AppTables.colTxDeletedAt} IS NULL',
      't.${AppTables.colTxOccurredDate} = ?',
    ];
    final args = <dynamic>[today];

    if (type != null) {
      where.add('t.${AppTables.colTxType} = ?');
      args.add(type);
    }

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        c.${AppTables.colCatName} AS category_name,
        c.${AppTables.colCatEmoji} AS category_emoji,
        w.${AppTables.colWalletName} AS wallet_name,
        w.${AppTables.colWalletEmoji} AS wallet_emoji,
        tw.${AppTables.colWalletName} AS to_wallet_name,
        tw.${AppTables.colWalletEmoji} AS to_wallet_emoji
      FROM ${AppTables.transactions} t
      LEFT JOIN ${AppTables.categories} c ON c.${AppTables.colCatId} = t.${AppTables.colTxCategoryId}
      LEFT JOIN ${AppTables.wallets} w ON w.${AppTables.colWalletId} = t.${AppTables.colTxWalletId}
      LEFT JOIN ${AppTables.wallets} tw ON tw.${AppTables.colWalletId} = t.${AppTables.colTxToWalletId}
      WHERE ${where.join(' AND ')}
      ORDER BY t.${AppTables.colTxOccurredTime} DESC, t.${AppTables.colTxId} DESC
    ''', args);

    return results.map((e) => TransactionItem.fromMap(e)).toList();
  }

  /// Range query for monthly transactions: occurred_date >= 'YYYY-MM-01' AND occurred_date < next month
  Future<List<TransactionItem>> getTransactionsForMonth(int year, int month, {String? type}) async {
    final db = await _db;
    final (startStr, endStr) = getMonthRange(year, month);

    final where = <String>[
      't.${AppTables.colTxDeletedAt} IS NULL',
      't.${AppTables.colTxOccurredDate} >= ?',
      't.${AppTables.colTxOccurredDate} < ?',
    ];
    final args = <dynamic>[startStr, endStr];

    if (type != null) {
      where.add('t.${AppTables.colTxType} = ?');
      args.add(type);
    }

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        c.${AppTables.colCatName} AS category_name,
        c.${AppTables.colCatEmoji} AS category_emoji,
        w.${AppTables.colWalletName} AS wallet_name,
        w.${AppTables.colWalletEmoji} AS wallet_emoji,
        tw.${AppTables.colWalletName} AS to_wallet_name,
        tw.${AppTables.colWalletEmoji} AS to_wallet_emoji
      FROM ${AppTables.transactions} t
      LEFT JOIN ${AppTables.categories} c ON c.${AppTables.colCatId} = t.${AppTables.colTxCategoryId}
      LEFT JOIN ${AppTables.wallets} w ON w.${AppTables.colWalletId} = t.${AppTables.colTxWalletId}
      LEFT JOIN ${AppTables.wallets} tw ON tw.${AppTables.colWalletId} = t.${AppTables.colTxToWalletId}
      WHERE ${where.join(' AND ')}
      ORDER BY t.${AppTables.colTxOccurredDate} DESC, t.${AppTables.colTxOccurredTime} DESC, t.${AppTables.colTxId} DESC
    ''', args);

    return results.map((e) => TransactionItem.fromMap(e)).toList();
  }

  /// Keyset pagination on (occurred_date, occurred_time, id)
  Future<List<TransactionItem>> getPaginatedTransactions({
    int limit = 30,
    String? cursorDate,
    String? cursorTime,
    int? cursorId,
    int? walletId,
    String? type,
  }) async {
    final db = await _db;
    final where = <String>['t.${AppTables.colTxDeletedAt} IS NULL'];
    final args = <dynamic>[];

    if (walletId != null) {
      where.add('(t.${AppTables.colTxWalletId} = ? OR t.${AppTables.colTxToWalletId} = ?)');
      args.addAll([walletId, walletId]);
    }

    if (type != null) {
      where.add('t.${AppTables.colTxType} = ?');
      args.add(type);
    }

    if (cursorDate != null && cursorTime != null && cursorId != null) {
      where.add('''
        (
          t.${AppTables.colTxOccurredDate} < ? 
          OR (t.${AppTables.colTxOccurredDate} = ? AND t.${AppTables.colTxOccurredTime} < ?)
          OR (t.${AppTables.colTxOccurredDate} = ? AND t.${AppTables.colTxOccurredTime} = ? AND t.${AppTables.colTxId} < ?)
        )
      ''');
      args.addAll([cursorDate, cursorDate, cursorTime, cursorDate, cursorTime, cursorId]);
    }

    args.add(limit);

    final results = await db.rawQuery('''
      SELECT 
        t.*,
        c.${AppTables.colCatName} AS category_name,
        c.${AppTables.colCatEmoji} AS category_emoji,
        w.${AppTables.colWalletName} AS wallet_name,
        w.${AppTables.colWalletEmoji} AS wallet_emoji,
        tw.${AppTables.colWalletName} AS to_wallet_name,
        tw.${AppTables.colWalletEmoji} AS to_wallet_emoji
      FROM ${AppTables.transactions} t
      LEFT JOIN ${AppTables.categories} c ON c.${AppTables.colCatId} = t.${AppTables.colTxCategoryId}
      LEFT JOIN ${AppTables.wallets} w ON w.${AppTables.colWalletId} = t.${AppTables.colTxWalletId}
      LEFT JOIN ${AppTables.wallets} tw ON tw.${AppTables.colWalletId} = t.${AppTables.colTxToWalletId}
      WHERE ${where.join(' AND ')}
      ORDER BY t.${AppTables.colTxOccurredDate} DESC, t.${AppTables.colTxOccurredTime} DESC, t.${AppTables.colTxId} DESC
      LIMIT ?
    ''', args);

    return results.map((e) => TransactionItem.fromMap(e)).toList();
  }

  /// Monthly stats queries running concurrently via Future.wait:
  /// 1. Monthly total expense
  /// 2. Category spending breakdown (includes active categories + spent deleted categories, and uncategorized)
  /// 3. Wallet spending breakdown
  Future<MonthlyStatsResult> getMonthlyStats(int year, int month) async {
    final db = await _db;
    final (startStr, endStr) = getMonthRange(year, month);

    final totalQuery = db.rawQuery('''
      SELECT COALESCE(SUM(${AppTables.colTxAmountCents}), 0) AS total_cents
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxType} = 'expense'
        AND ${AppTables.colTxDeletedAt} IS NULL
        AND ${AppTables.colTxOccurredDate} >= ? 
        AND ${AppTables.colTxOccurredDate} < ?
    ''', [startStr, endStr]);

    final categoryQuery = db.rawQuery('''
      SELECT 
        c.${AppTables.colCatId} AS category_id,
        COALESCE(SUM(t.${AppTables.colTxAmountCents}), 0) AS total_cents
      FROM ${AppTables.categories} c
      LEFT JOIN ${AppTables.transactions} t 
        ON t.${AppTables.colTxCategoryId} = c.${AppTables.colCatId}
        AND t.${AppTables.colTxType} = 'expense'
        AND t.${AppTables.colTxDeletedAt} IS NULL
        AND t.${AppTables.colTxOccurredDate} >= ? 
        AND t.${AppTables.colTxOccurredDate} < ?
      WHERE c.${AppTables.colCatKind} = 'expense'
        AND (c.${AppTables.colCatDeletedAt} IS NULL OR t.${AppTables.colTxId} IS NOT NULL)
      GROUP BY c.${AppTables.colCatId}
      HAVING (c.${AppTables.colCatDeletedAt} IS NULL) OR (total_cents > 0)

      UNION ALL

      SELECT 
        NULL AS category_id,
        COALESCE(SUM(t.${AppTables.colTxAmountCents}), 0) AS total_cents
      FROM ${AppTables.transactions} t
      WHERE t.${AppTables.colTxType} = 'expense'
        AND t.${AppTables.colTxCategoryId} IS NULL
        AND t.${AppTables.colTxDeletedAt} IS NULL
        AND t.${AppTables.colTxOccurredDate} >= ? 
        AND t.${AppTables.colTxOccurredDate} < ?
      HAVING total_cents > 0
    ''', [startStr, endStr, startStr, endStr]);

    final walletQuery = db.rawQuery('''
      SELECT 
        w.${AppTables.colWalletId} AS wallet_id,
        COALESCE(SUM(t.${AppTables.colTxAmountCents}), 0) AS total_cents
      FROM ${AppTables.wallets} w
      LEFT JOIN ${AppTables.transactions} t 
        ON t.${AppTables.colTxWalletId} = w.${AppTables.colWalletId}
        AND t.${AppTables.colTxType} = 'expense'
        AND t.${AppTables.colTxDeletedAt} IS NULL
        AND t.${AppTables.colTxOccurredDate} >= ? 
        AND t.${AppTables.colTxOccurredDate} < ?
      WHERE w.${AppTables.colWalletIsArchived} = 0 OR t.${AppTables.colTxId} IS NOT NULL
      GROUP BY w.${AppTables.colWalletId}
      HAVING (w.${AppTables.colWalletIsArchived} = 0) OR (total_cents > 0)
    ''', [startStr, endStr]);

    final results = await Future.wait([totalQuery, categoryQuery, walletQuery]);

    final totalCents = (results[0].first['total_cents'] as int?) ?? 0;

    final catMap = <int?, int>{};
    for (final row in results[1]) {
      final catId = row['category_id'] as int?;
      final cents = (row['total_cents'] as int?) ?? 0;
      catMap[catId] = cents;
    }

    final walletMap = <int, int>{};
    for (final row in results[2]) {
      final wId = row['wallet_id'] as int;
      final cents = (row['total_cents'] as int?) ?? 0;
      walletMap[wId] = cents;
    }

    return MonthlyStatsResult(
      totalExpenseCents: totalCents,
      categoryTotalsCents: catMap,
      walletTotalsCents: walletMap,
    );
  }

  /// Clears ALL transactions ledger data in one single database transaction.
  /// Preserves categories, wallets, reminder_slots, and app_settings.
  /// Balances will strictly equal opening balances.
  Future<int> clearAllLedgerData() async {
    final db = await _db;
    return await db.transaction((txn) async {
      return await txn.delete(AppTables.transactions);
    });
  }

  /// Exports all ledger rows + categories + wallets + settings as structured JSON with schema_version: 4
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await _db;
    final transactions = await db.query(AppTables.transactions);
    final categories = await db.query(AppTables.categories);
    final wallets = await db.query(AppTables.wallets);
    final settings = await db.query(AppTables.appSettings);
    final reminders = await db.query(AppTables.reminderSlots);

    return {
      'schema_version': 4,
      'exported_at': DateTime.now().toIso8601String(),
      'wallets': wallets,
      'categories': categories,
      'transactions': transactions,
      'reminder_slots': reminders,
      'app_settings': settings,
    };
  }

  Future<List<Map<String, dynamic>>> exportAllTransactions() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT 
        t.*,
        c.${AppTables.colCatName} AS category_name,
        c.${AppTables.colCatEmoji} AS category_emoji,
        w.${AppTables.colWalletName} AS wallet_name,
        tw.${AppTables.colWalletName} AS to_wallet_name
      FROM ${AppTables.transactions} t
      LEFT JOIN ${AppTables.categories} c ON c.${AppTables.colCatId} = t.${AppTables.colTxCategoryId}
      LEFT JOIN ${AppTables.wallets} w ON w.${AppTables.colWalletId} = t.${AppTables.colTxWalletId}
      LEFT JOIN ${AppTables.wallets} tw ON tw.${AppTables.colWalletId} = t.${AppTables.colTxToWalletId}
      WHERE t.${AppTables.colTxDeletedAt} IS NULL
      ORDER BY t.${AppTables.colTxOccurredDate} DESC, t.${AppTables.colTxOccurredTime} DESC
    ''');
  }
}
