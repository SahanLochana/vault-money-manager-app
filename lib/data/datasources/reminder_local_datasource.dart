import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/database/tables.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:sqflite/sqflite.dart';

class ReminderLocalDatasource {
  final AppDatabase appDatabase;

  ReminderLocalDatasource({required this.appDatabase});

  Future<Database> get _db => appDatabase.database;

  Future<List<ReminderSlot>> getAllReminders() async {
    final db = await _db;
    final maps = await db.query(
      AppTables.reminderSlots,
      orderBy: '${AppTables.colReminderTime} ASC, ${AppTables.colReminderId} ASC',
    );
    return maps.map((e) => ReminderSlot.fromMap(e)).toList();
  }

  Future<ReminderSlot?> getReminderById(int id) async {
    final db = await _db;
    final maps = await db.query(
      AppTables.reminderSlots,
      where: '${AppTables.colReminderId} = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ReminderSlot.fromMap(maps.first);
  }

  Future<int> insertReminder(ReminderSlot slot) async {
    final db = await _db;
    return await db.insert(AppTables.reminderSlots, slot.toMap());
  }

  Future<int> updateReminder(ReminderSlot slot) async {
    final db = await _db;
    return await db.update(
      AppTables.reminderSlots,
      slot.toMap(),
      where: '${AppTables.colReminderId} = ?',
      whereArgs: [slot.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await _db;
    return await db.delete(
      AppTables.reminderSlots,
      where: '${AppTables.colReminderId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleReminder(int id, bool isActive) async {
    final db = await _db;
    return await db.update(
      AppTables.reminderSlots,
      {AppTables.colReminderIsActive: isActive ? 1 : 0},
      where: '${AppTables.colReminderId} = ?',
      whereArgs: [id],
    );
  }
}
