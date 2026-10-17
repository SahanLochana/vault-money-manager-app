import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:sqflite/sqflite.dart';

class CategoryLocalDatasource {
  final AppDatabase appDatabase;

  CategoryLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  Future<List<Category>> getAllCategories({String? kind}) async {
    final db = await _db;
    final whereClauses = <String>['${AppTables.colCatDeletedAt} IS NULL'];
    final whereArgs = <dynamic>[];

    if (kind != null) {
      whereClauses.add('${AppTables.colCatKind} = ?');
      whereArgs.add(kind);
    }

    final maps = await db.query(
      AppTables.categories,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: '${AppTables.colCatSortOrder} ASC, ${AppTables.colCatId} ASC',
    );
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<List<Category>> getAllCategoriesIncludingDeleted({String? kind}) async {
    final db = await _db;
    final where = kind != null ? '${AppTables.colCatKind} = ?' : null;
    final whereArgs = kind != null ? [kind] : null;

    final maps = await db.query(
      AppTables.categories,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${AppTables.colCatSortOrder} ASC, ${AppTables.colCatId} ASC',
    );
    return maps.map((e) => Category.fromMap(e)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await _db;
    final maps = await db.query(
      AppTables.categories,
      where: '${AppTables.colCatId} = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> insertCategory(Category category) async {
    final db = await _db;
    return await db.insert(AppTables.categories, category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await _db;
    return await db.update(
      AppTables.categories,
      category.toMap(),
      where: '${AppTables.colCatId} = ?',
      whereArgs: [category.id],
    );
  }

  /// Soft deletes a category and removes its associated reminder slots in a single transaction.
  /// Returns the IDs of the deleted reminder slots so their notification alarms can be canceled.
  /// Transactions are NEVER rewritten or reassigned.
  Future<List<int>> deleteCategory(int id) async {
    final db = await _db;
    return await db.transaction((txn) async {
      // 1. Soft-delete category
      await txn.update(
        AppTables.categories,
        {
          AppTables.colCatDeletedAt: DateTime.now().toIso8601String(),
        },
        where: '${AppTables.colCatId} = ?',
        whereArgs: [id],
      );

      // Find reminder slots to cancel notifications
      final reminderRows = await txn.query(
        AppTables.reminderSlots,
        columns: [AppTables.colReminderId],
        where: '${AppTables.colReminderCategoryId} = ?',
        whereArgs: [id],
      );
      final reminderIds = reminderRows.map((r) => r[AppTables.colReminderId] as int).toList();

      // 2. Remove reminder slots linked to this category
      await txn.delete(
        AppTables.reminderSlots,
        where: '${AppTables.colReminderCategoryId} = ?',
        whereArgs: [id],
      );

      return reminderIds;
    });
  }

  Future<int> countTransactionsForCategory(int id) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM ${AppTables.transactions}
      WHERE ${AppTables.colTxCategoryId} = ? 
        AND ${AppTables.colTxDeletedAt} IS NULL
      ''',
      [id],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countRemindersForCategory(int id) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM ${AppTables.reminderSlots}
      WHERE ${AppTables.colReminderCategoryId} = ?
      ''',
      [id],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> restoreCategory(int id) async {
    final db = await _db;
    await db.update(
      AppTables.categories,
      {
        AppTables.colCatDeletedAt: null,
      },
      where: '${AppTables.colCatId} = ?',
      whereArgs: [id],
    );
  }

  Future<bool> categoryHasExpenses(int id) async {
    final count = await countTransactionsForCategory(id);
    return count > 0;
  }
}
