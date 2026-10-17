import 'package:sqflite/sqflite.dart';
import 'package:money_management_app/data/database/tables.dart';

class DatabaseSchema {
  static Future<void> createAll(Database db) async {
    // 1. Wallets table
    await db.execute('''
      CREATE TABLE ${AppTables.wallets} (
        ${AppTables.colWalletId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppTables.colWalletName} TEXT NOT NULL,
        ${AppTables.colWalletEmoji} TEXT NOT NULL,
        ${AppTables.colWalletOpeningBalanceCents} INTEGER NOT NULL DEFAULT 0,
        ${AppTables.colWalletSortOrder} INTEGER NOT NULL DEFAULT 0,
        ${AppTables.colWalletIsArchived} INTEGER NOT NULL DEFAULT 0,
        ${AppTables.colWalletCreatedAt} TEXT NOT NULL
      )
    ''');

    // 2. Categories table (kind: 'expense' or 'income')
    await db.execute('''
      CREATE TABLE ${AppTables.categories} (
        ${AppTables.colCatId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppTables.colCatKind} TEXT NOT NULL CHECK(${AppTables.colCatKind} IN ('expense', 'income')),
        ${AppTables.colCatName} TEXT NOT NULL,
        ${AppTables.colCatEmoji} TEXT NOT NULL,
        ${AppTables.colCatDefaultAmountCents} INTEGER NOT NULL DEFAULT 0 CHECK(${AppTables.colCatDefaultAmountCents} >= 0),
        ${AppTables.colCatSortOrder} INTEGER NOT NULL DEFAULT 0,
        ${AppTables.colCatDeletedAt} TEXT,
        ${AppTables.colCatCreatedAt} TEXT NOT NULL
      )
    ''');

    // Partial unique index: unique (kind, name) among non-deleted categories
    await db.execute('''
      CREATE UNIQUE INDEX idx_categories_kind_name_active 
      ON ${AppTables.categories} (${AppTables.colCatKind}, ${AppTables.colCatName}) 
      WHERE ${AppTables.colCatDeletedAt} IS NULL
    ''');

    // 3. Transactions table (Single ledger)
    await db.execute('''
      CREATE TABLE ${AppTables.transactions} (
        ${AppTables.colTxId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppTables.colTxType} TEXT NOT NULL CHECK(${AppTables.colTxType} IN ('expense', 'income', 'transfer')),
        ${AppTables.colTxAmountCents} INTEGER NOT NULL CHECK(${AppTables.colTxAmountCents} > 0),
        ${AppTables.colTxWalletId} INTEGER NOT NULL,
        ${AppTables.colTxToWalletId} INTEGER,
        ${AppTables.colTxCategoryId} INTEGER,
        ${AppTables.colTxOccurredDate} TEXT NOT NULL,
        ${AppTables.colTxOccurredTime} TEXT NOT NULL,
        ${AppTables.colTxNote} TEXT,
        ${AppTables.colTxDeletedAt} TEXT,
        ${AppTables.colTxCreatedAt} TEXT NOT NULL,
        ${AppTables.colTxUpdatedAt} TEXT NOT NULL,
        FOREIGN KEY (${AppTables.colTxWalletId}) REFERENCES ${AppTables.wallets} (${AppTables.colWalletId}) ON DELETE RESTRICT,
        FOREIGN KEY (${AppTables.colTxToWalletId}) REFERENCES ${AppTables.wallets} (${AppTables.colWalletId}) ON DELETE RESTRICT,
        FOREIGN KEY (${AppTables.colTxCategoryId}) REFERENCES ${AppTables.categories} (${AppTables.colCatId}) ON DELETE RESTRICT,
        CHECK (
          (${AppTables.colTxType} = 'transfer' AND ${AppTables.colTxToWalletId} IS NOT NULL AND ${AppTables.colTxToWalletId} <> ${AppTables.colTxWalletId} AND ${AppTables.colTxCategoryId} IS NULL)
          OR
          (${AppTables.colTxType} IN ('expense', 'income') AND ${AppTables.colTxToWalletId} IS NULL)
        )
      )
    ''');

    // Indexes for transactions table
    await db.execute('CREATE INDEX idx_transactions_date ON ${AppTables.transactions} (${AppTables.colTxOccurredDate})');
    await db.execute('CREATE INDEX idx_transactions_wallet ON ${AppTables.transactions} (${AppTables.colTxWalletId})');
    await db.execute('CREATE INDEX idx_transactions_to_wallet ON ${AppTables.transactions} (${AppTables.colTxToWalletId})');
    await db.execute('CREATE INDEX idx_transactions_category ON ${AppTables.transactions} (${AppTables.colTxCategoryId})');
    await db.execute('CREATE INDEX idx_transactions_type_date ON ${AppTables.transactions} (${AppTables.colTxType}, ${AppTables.colTxOccurredDate})');
    await db.execute('CREATE INDEX idx_transactions_active ON ${AppTables.transactions} (${AppTables.colTxOccurredDate}, ${AppTables.colTxOccurredTime}, ${AppTables.colTxId}) WHERE ${AppTables.colTxDeletedAt} IS NULL');

    // 4. Reminder Slots table
    await db.execute('''
      CREATE TABLE ${AppTables.reminderSlots} (
        ${AppTables.colReminderId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${AppTables.colReminderCategoryId} INTEGER NOT NULL,
        ${AppTables.colReminderTime} TEXT NOT NULL,
        ${AppTables.colReminderDefaultAmountCents} INTEGER CHECK(${AppTables.colReminderDefaultAmountCents} IS NULL OR ${AppTables.colReminderDefaultAmountCents} >= 0),
        ${AppTables.colReminderIsActive} INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (${AppTables.colReminderCategoryId}) REFERENCES ${AppTables.categories} (${AppTables.colCatId}) ON DELETE RESTRICT
      )
    ''');
    await db.execute('CREATE INDEX idx_reminder_slots_category ON ${AppTables.reminderSlots} (${AppTables.colReminderCategoryId})');

    // 5. App Settings table
    await db.execute('''
      CREATE TABLE ${AppTables.appSettings} (
        ${AppTables.colSettingKey} TEXT PRIMARY KEY,
        ${AppTables.colSettingValue} TEXT NOT NULL
      )
    ''');
  }

  static Future<void> seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Seed Starter Expense Categories
    final expenseCategories = [
      {'kind': 'expense', 'name': 'Breakfast', 'emoji': '🍳', 'default_amount_cents': 8000, 'sort_order': 0, 'created_at': now},
      {'kind': 'expense', 'name': 'Lunch', 'emoji': '🍔', 'default_amount_cents': 15000, 'sort_order': 1, 'created_at': now},
      {'kind': 'expense', 'name': 'Dinner', 'emoji': '🌙', 'default_amount_cents': 18000, 'sort_order': 2, 'created_at': now},
      {'kind': 'expense', 'name': 'Lending', 'emoji': '🤝', 'default_amount_cents': 0, 'sort_order': 3, 'created_at': now},
      {'kind': 'expense', 'name': 'Other', 'emoji': '🍿', 'default_amount_cents': 0, 'sort_order': 4, 'created_at': now},
    ];

    int? breakfastId;
    for (final cat in expenseCategories) {
      final insertedId = await db.insert(AppTables.categories, cat);
      if (cat['name'] == 'Breakfast') {
        breakfastId = insertedId;
      }
    }

    // 2. Seed Starter Income Categories
    final incomeCategories = [
      {'kind': 'income', 'name': 'From Home', 'emoji': '🏠', 'default_amount_cents': 0, 'sort_order': 0, 'created_at': now},
      {'kind': 'income', 'name': 'Mahapola', 'emoji': '🎓', 'default_amount_cents': 0, 'sort_order': 1, 'created_at': now},
      {'kind': 'income', 'name': 'Bursary', 'emoji': '🏛️', 'default_amount_cents': 0, 'sort_order': 2, 'created_at': now},
      {'kind': 'income', 'name': 'Other', 'emoji': '🍿', 'default_amount_cents': 0, 'sort_order': 3, 'created_at': now},
    ];

    for (final cat in incomeCategories) {
      await db.insert(AppTables.categories, cat);
    }

    // 3. Seed Starter Wallets
    final wallets = [
      {'name': 'In Hand', 'emoji': '👛', 'opening_balance_cents': 0, 'sort_order': 0, 'is_archived': 0, 'created_at': now},
      {'name': 'In Bank', 'emoji': '🏦', 'opening_balance_cents': 0, 'sort_order': 1, 'is_archived': 0, 'created_at': now},
    ];

    for (final wallet in wallets) {
      await db.insert(AppTables.wallets, wallet);
    }

    // 4. Seed Starter Reminder Slot using dynamically returned Breakfast category id
    if (breakfastId != null) {
      await db.insert(AppTables.reminderSlots, {
        'category_id': breakfastId,
        'time': '08:00',
        'default_amount_cents': null, // NULL = fallback to category's default_amount_cents
        'is_active': 0,
      });
    }

    // 5. Seed Starter App Settings
    final defaultSettings = {
      'daily_budget': '500.0',
      'snooze_duration_minutes': '15',
      'wallet_setup_done': 'false',
    };

    for (final entry in defaultSettings.entries) {
      await db.insert(AppTables.appSettings, {
        AppTables.colSettingKey: entry.key,
        AppTables.colSettingValue: entry.value,
      });
    }
  }
}
