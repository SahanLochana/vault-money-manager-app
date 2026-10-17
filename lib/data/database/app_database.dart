import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:money_management_app/data/database/schema.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  final Database? _customDatabase;

  AppDatabase._init() : _customDatabase = null;
  AppDatabase.withDatabase(Database db) : _customDatabase = db;

  Future<Database> get database async {
    final custom = _customDatabase;
    if (custom != null) return custom;
    final db = _database;
    if (db != null) return db;
    _database = await _initDB('vault_money.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: _onConfigure,
      onCreate: _createDB,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _createDB(Database db, int version) async {
    await DatabaseSchema.createAll(db);
    await DatabaseSchema.seedInitialData(db);
  }

  Future<void> close() async {
    final db = _customDatabase ?? _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
