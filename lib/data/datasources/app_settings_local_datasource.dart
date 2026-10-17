import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:sqflite/sqflite.dart';

class AppSettingsLocalDatasource {
  final AppDatabase appDatabase;

  AppSettingsLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  Future<String?> getSetting(String key) async {
    final db = await _db;
    final results = await db.query(
      AppTables.appSettings,
      columns: [AppTables.colSettingValue],
      where: '${AppTables.colSettingKey} = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first[AppTables.colSettingValue] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      AppTables.appSettings,
      {
        AppTables.colSettingKey: key,
        AppTables.colSettingValue: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getDouble(String key, double defaultValue) async {
    final val = await getSetting(key);
    if (val == null) return defaultValue;
    return double.tryParse(val) ?? defaultValue;
  }

  Future<void> setDouble(String key, double value) async {
    await setSetting(key, value.toString());
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    final val = await getSetting(key);
    if (val == null) return defaultValue;
    return val.toLowerCase() == 'true' || val == '1';
  }

  Future<void> setBool(String key, bool value) async {
    await setSetting(key, value ? 'true' : 'false');
  }

  Future<int> getInt(String key, int defaultValue) async {
    final val = await getSetting(key);
    if (val == null) return defaultValue;
    return int.tryParse(val) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    await setSetting(key, value.toString());
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await _db;
    final results = await db.query(AppTables.appSettings);
    final map = <String, String>{};
    for (final row in results) {
      final k = row[AppTables.colSettingKey] as String;
      final v = row[AppTables.colSettingValue] as String;
      map[k] = v;
    }
    return map;
  }

  Future<void> deleteSetting(String key) async {
    final db = await _db;
    await db.delete(
      AppTables.appSettings,
      where: '${AppTables.colSettingKey} = ?',
      whereArgs: [key],
    );
  }
}
