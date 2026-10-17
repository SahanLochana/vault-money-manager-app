import 'package:intl/intl.dart';
import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/expense.dart';
import 'package:sqflite/sqflite.dart';

class ExpenseLocalDatasource {
  final AppDatabase appDatabase;

  ExpenseLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  Future<int> insertExpense(Expense expense) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.insert(AppTables.transactions, {
      if (expense.id != null) AppTables.colTxId: expense.id,
      AppTables.colTxType: 'expense',
      AppTables.colTxAmountCents: expense.amountCents,
      AppTables.colTxWalletId: expense.walletId,
      AppTables.colTxToWalletId: null,
      AppTables.colTxCategoryId: expense.categoryId,
      AppTables.colTxOccurredDate: expense.expenseDate,
      AppTables.colTxOccurredTime: expense.expenseTime,
      AppTables.colTxNote: expense.note,
      AppTables.colTxDeletedAt: expense.isDeleted ? now : null,
      AppTables.colTxCreatedAt: expense.createdAt.toIso8601String(),
      AppTables.colTxUpdatedAt: expense.updatedAt.toIso8601String(),
    });
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await _db;
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxAmountCents: expense.amountCents,
        AppTables.colTxWalletId: expense.walletId,
        AppTables.colTxCategoryId: expense.categoryId,
        AppTables.colTxOccurredDate: expense.expenseDate,
        AppTables.colTxOccurredTime: expense.expenseTime,
        AppTables.colTxNote: expense.note,
        AppTables.colTxUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [expense.id, 'expense'],
    );
  }

  Future<int> softDeleteExpense(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: now,
        AppTables.colTxUpdatedAt: now,
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'expense'],
    );
  }

  Future<int> restoreExpense(int id) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      AppTables.transactions,
      {
        AppTables.colTxDeletedAt: null,
        AppTables.colTxUpdatedAt: now,
      },
      where: '${AppTables.colTxId} = ? AND ${AppTables.colTxType} = ?',
      whereArgs: [id, 'expense'],
    );
  }

  Expense _rowToExpense(Map<String, dynamic> row) {
    return Expense(
      id: row[AppTables.colTxId] as int?,
      categoryId: (row[AppTables.colTxCategoryId] as int?) ?? 0,
      amountCents: row[AppTables.colTxAmountCents] as int,
      walletId: row[AppTables.colTxWalletId] as int,
      expenseDate: row[AppTables.colTxOccurredDate] as String,
      expenseTime: row[AppTables.colTxOccurredTime] as String,
      note: row[AppTables.colTxNote] as String?,
      isDeleted: row[AppTables.colTxDeletedAt] != null,
      createdAt: DateTime.parse(row[AppTables.colTxCreatedAt] as String),
      updatedAt: DateTime.parse(row[AppTables.colTxUpdatedAt] as String),
    );
  }

  Future<List<Expense>> getTodayExpenses() async {
    final db = await _db;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} = ?',
      whereArgs: ['expense', todayStr],
      orderBy: '${AppTables.colTxOccurredTime} DESC, ${AppTables.colTxCreatedAt} DESC',
    );

    return maps.map(_rowToExpense).toList();
  }

  Future<List<Expense>> getAllActiveExpenses() async {
    final db = await _db;
    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ?',
      whereArgs: ['expense'],
      orderBy: '${AppTables.colTxOccurredDate} DESC, ${AppTables.colTxOccurredTime} DESC, ${AppTables.colTxCreatedAt} DESC',
    );

    return maps.map(_rowToExpense).toList();
  }

  /// Range query replacing LIKE 'YYYY-MM%'
  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final db = await _db;
    final (startStr, endStr) = TransactionLocalDatasource.getMonthRange(year, month);

    final maps = await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} >= ? AND ${AppTables.colTxOccurredDate} < ?',
      whereArgs: ['expense', startStr, endStr],
      orderBy: '${AppTables.colTxOccurredDate} DESC, ${AppTables.colTxOccurredTime} DESC, ${AppTables.colTxCreatedAt} DESC',
    );

    return maps.map(_rowToExpense).toList();
  }

  Future<int> getTodayTotalCents() async {
    final db = await _db;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(${AppTables.colTxAmountCents}), 0) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} = ?
      ''',
      ['expense', todayStr],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Range query replacing LIKE 'YYYY-MM%'
  Future<int> getMonthlyTotalCents(int year, int month) async {
    final db = await _db;
    final (startStr, endStr) = TransactionLocalDatasource.getMonthRange(year, month);

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(${AppTables.colTxAmountCents}), 0) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} >= ? AND ${AppTables.colTxOccurredDate} < ?
      ''',
      ['expense', startStr, endStr],
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Range query replacing LIKE 'YYYY-MM%'
  Future<Map<int, int>> getMonthlyCategoryTotalsCents(int year, int month) async {
    final db = await _db;
    final (startStr, endStr) = TransactionLocalDatasource.getMonthRange(year, month);

    final results = await db.rawQuery(
      '''
      SELECT ${AppTables.colTxCategoryId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} >= ? AND ${AppTables.colTxOccurredDate} < ?
      GROUP BY ${AppTables.colTxCategoryId}
      ''',
      ['expense', startStr, endStr],
    );

    final Map<int, int> totals = {};
    for (final row in results) {
      final categoryId = row[AppTables.colTxCategoryId] as int?;
      if (categoryId != null) {
        final total = (row['total'] as int?) ?? 0;
        totals[categoryId] = total;
      }
    }
    return totals;
  }

  /// Range query replacing LIKE 'YYYY-MM%'
  Future<Map<int, int>> getMonthlyWalletTotalsCents(int year, int month) async {
    final db = await _db;
    final (startStr, endStr) = TransactionLocalDatasource.getMonthRange(year, month);

    final results = await db.rawQuery(
      '''
      SELECT ${AppTables.colTxWalletId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ? AND ${AppTables.colTxOccurredDate} >= ? AND ${AppTables.colTxOccurredDate} < ?
      GROUP BY ${AppTables.colTxWalletId}
      ''',
      ['expense', startStr, endStr],
    );

    final Map<int, int> totals = {};
    for (final row in results) {
      final walletId = row[AppTables.colTxWalletId] as int;
      final total = (row['total'] as int?) ?? 0;
      totals[walletId] = total;
    }
    return totals;
  }

  Future<Map<int, int>> getAllWalletExpenseTotalsCents() async {
    final db = await _db;
    final results = await db.rawQuery(
      '''
      SELECT ${AppTables.colTxWalletId}, SUM(${AppTables.colTxAmountCents}) as total
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ?
      GROUP BY ${AppTables.colTxWalletId}
      ''',
      ['expense'],
    );

    final Map<int, int> totals = {};
    for (final row in results) {
      final walletId = row[AppTables.colTxWalletId] as int;
      final total = (row['total'] as int?) ?? 0;
      totals[walletId] = total;
    }
    return totals;
  }

  /// Clears ALL ledger rows (expense, income, transfer) in a single transaction.
  Future<void> clearAllExpenses() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(AppTables.transactions);
    });
  }

  Future<List<Map<String, dynamic>>> exportAllExpenses() async {
    final db = await _db;
    return await db.query(
      AppTables.transactions,
      where: '${AppTables.colTxDeletedAt} IS NULL AND ${AppTables.colTxType} = ?',
      whereArgs: ['expense'],
      orderBy: '${AppTables.colTxOccurredDate} DESC',
    );
  }
}
