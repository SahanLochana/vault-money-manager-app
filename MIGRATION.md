# Vault Local Database Redesign (Schema Version 1)

## Architecture Overview
The local database of Vault has been redesigned from the ground up as a clean, single-ledger relational database powered by SQLite (`sqflite`). It completely eliminates the previous schema fragmentation where money was split across three disparate tables (`expenses`, `wallet_funds`, and `wallet_transfers`).

---

## 1. Database Schema Diagram

```
+------------------------------------------------------------------------+
|                                wallets                                 |
+------------------------------------------------------------------------+
| id                     INTEGER PRIMARY KEY AUTOINCREMENT               |
| name                   TEXT NOT NULL                                   |
| emoji                  TEXT NOT NULL                                   |
| opening_balance_cents  INTEGER NOT NULL DEFAULT 0                      |
| sort_order             INTEGER NOT NULL DEFAULT 0                      |
| is_archived            INTEGER NOT NULL DEFAULT 0                      |
| created_at             TEXT NOT NULL                                   |
+------------------------------------------------------------------------+
         | 1                                              | 1
         |                                                |
         | (source/destination)                           | (transfer destination)
         |                                                |
         v N                                              v N
+------------------------------------------------------------------------+
|                              transactions                              |
|                            (Single Ledger)                             |
+------------------------------------------------------------------------+
| id            INTEGER PRIMARY KEY AUTOINCREMENT                        |
| type          TEXT NOT NULL CHECK(type IN ('expense','income','transfer'))
| amount_cents  INTEGER NOT NULL CHECK(amount_cents > 0)                 |
| wallet_id     INTEGER NOT NULL -> REFERENCES wallets(id) RESTRICT      |
| to_wallet_id  INTEGER NULL     -> REFERENCES wallets(id) RESTRICT      |
| category_id   INTEGER NULL     -> REFERENCES categories(id) RESTRICT   |
| occurred_date TEXT NOT NULL    ('YYYY-MM-DD')                          |
| occurred_time TEXT NOT NULL    ('HH:mm')                               |
| note          TEXT NULL                                                |
| deleted_at    TEXT NULL        (NULL = active, soft-deleted timestamp) |
| created_at    TEXT NOT NULL                                            |
| updated_at    TEXT NOT NULL                                            |
+------------------------------------------------------------------------+
| CHECK:                                                                 |
| (type = 'transfer' AND to_wallet_id IS NOT NULL                         |
|  AND to_wallet_id <> wallet_id AND category_id IS NULL)                |
| OR                                                                     |
| (type IN ('expense', 'income') AND to_wallet_id IS NULL)               |
+------------------------------------------------------------------------+
         ^ N
         |
         | (categorization)
         |
         | 0..1
+------------------------------------------------------------------------+
|                               categories                               |
+------------------------------------------------------------------------+
| id                   INTEGER PRIMARY KEY AUTOINCREMENT                 |
| kind                 TEXT NOT NULL CHECK(kind IN ('expense', 'income'))|
| name                 TEXT NOT NULL                                     |
| emoji                TEXT NOT NULL                                     |
| default_amount_cents INTEGER NOT NULL DEFAULT 0 CHECK(amount >= 0)     |
| sort_order           INTEGER NOT NULL DEFAULT 0                        |
| deleted_at           TEXT NULL    (Soft delete only)                   |
| created_at           TEXT NOT NULL                                     |
+------------------------------------------------------------------------+
| UNIQUE INDEX: (kind, name) WHERE deleted_at IS NULL                    |
| NO is_system COLUMN - Every category is user-manageable                |
+------------------------------------------------------------------------+
         | 1
         |
         v 0..N
+------------------------------------------------------------------------+
|                             reminder_slots                             |
+------------------------------------------------------------------------+
| id                   INTEGER PRIMARY KEY AUTOINCREMENT                 |
| category_id          INTEGER NOT NULL -> REFERENCES categories(id)     |
| time                 TEXT NOT NULL ('HH:mm')                           |
| default_amount_cents INTEGER NULL CHECK(amount IS NULL OR amount >= 0) |
|                      (NULL = fallback to category default_amount_cents)|
| is_active            INTEGER NOT NULL DEFAULT 1                        |
+------------------------------------------------------------------------+
| NO is_system COLUMN                                                    |
+------------------------------------------------------------------------+

+------------------------------------------------------------------------+
|                              app_settings                              |
+------------------------------------------------------------------------+
| key                  TEXT PRIMARY KEY                                  |
| value                TEXT NOT NULL                                     |
+------------------------------------------------------------------------+
| Stores: daily_budget, snooze_duration_minutes, wallet_setup_done       |
+------------------------------------------------------------------------+
```

---

## 2. Design Decisions & Technical Justifications

### 2.1 Single Ledger Architecture (`transactions`)
- **Problem**: Previously, transactions were fragmented into three separate tables: `expenses`, `wallet_funds`, and `wallet_transfers`. Every wallet balance calculation required 5 separate aggregate queries across 3 tables, and the transaction timeline had to be merged, sorted, and paginated in Dart application memory.
- **Solution**: A unified double-entry-capable `transactions` ledger. All cash movements are rows in `transactions` with typed categories (`expense`, `income`, `transfer`).
- **Benefit**:
  - Wallet balances are computed in **one single SQLite query**.
  - History is loaded directly in SQL with efficient keyset pagination.
  - Atomic transactions guarantee balance integrity.

### 2.2 User-Managed Categories & Soft-Deletion
- **Problem**: Earlier, seed categories were marked with an immutable `is_system = 1` flag and hard-coded IDs, and deleting any category forcefully rewrote transaction history by reassigning transactions to a fallback category named 'Other'. Income categories lived outside SQLite in `SharedPreferences`.
- **Solution**:
  - `categories` now stores both `expense` and `income` kinds.
  - No `is_system` column. Every category is fully user-manageable.
  - Soft-delete strategy: deleting a category sets `deleted_at = datetime('now')`. Historical transactions keep their original `category_id`, name, and emoji.
  - Partial unique index: `CREATE UNIQUE INDEX idx_categories_kind_name_active ON categories(kind, name) WHERE deleted_at IS NULL;` ensures uniqueness among active categories while permitting previously deleted category names to be reused.
  - In the same database transaction that soft-deletes a category, any associated reminder slots for that category are deleted. Historical transactions are **never** rewritten or touched.

### 2.3 Strict Foreign Keys & Data Integrity
- **Foreign Keys**: Enabled at connection initialization via `PRAGMA foreign_keys = ON;` in `onConfigure`.
- **Action**: `ON DELETE RESTRICT` on all foreign keys. Since the application uses soft deletes for entities with transaction history, hard deletes of referenced wallets or categories are strictly prohibited at the database engine level.
- **CHECK Constraints**: Table-level CHECK constraints enforce valid combinations:
  - Transfers must have `to_wallet_id NOT NULL`, `to_wallet_id <> wallet_id`, and `category_id IS NULL`.
  - Non-transfers must have `to_wallet_id IS NULL`.
  - Amounts must be strictly positive integers (`amount_cents > 0`).

### 2.4 Indexing Strategy
1. `transactions(occurred_date)`: Accelerates date filtering and range checks.
2. `transactions(wallet_id)` & `transactions(to_wallet_id)`: Enables instant single-query wallet balance aggregations and wallet-filtered history.
3. `transactions(category_id)`: Optimizes category breakdown stats and integrity checks.
4. `transactions(type, occurred_date)`: Speeds up filtered monthly spending and income calculations.
5. `transactions(occurred_date, occurred_time, id) WHERE deleted_at IS NULL`: High-performance compound index for active keyset pagination.
6. `reminder_slots(category_id)`: Optimizes alert lookups and cascading cleanup.

### 2.5 Replacing `LIKE 'YYYY-MM%'` with Range Queries
- **Problem**: `occurred_date LIKE '2026-10%'` forces a full table scan or text collation scan in SQLite and cannot leverage index range scanning efficiently.
- **Solution**: All date queries now use strict range comparisons:
  `occurred_date >= 'YYYY-MM-01' AND occurred_date < 'YYYY-(MM+1)-01'`.

### 2.6 Single-Query Wallet Balances
Wallet balances are computed in a single query with `SUM(CASE ...)`:
```sql
SELECT 
  w.id,
  w.name,
  w.emoji,
  w.opening_balance_cents,
  w.sort_order,
  w.is_archived,
  w.created_at,
  (
    w.opening_balance_cents +
    COALESCE(SUM(CASE 
      WHEN t.type = 'income' AND t.wallet_id = w.id THEN t.amount_cents
      WHEN t.type = 'transfer' AND t.to_wallet_id = w.id THEN t.amount_cents
      WHEN t.type = 'expense' AND t.wallet_id = w.id THEN -t.amount_cents
      WHEN t.type = 'transfer' AND t.wallet_id = w.id THEN -t.amount_cents
      ELSE 0
    END), 0)
  ) AS balance_cents
FROM wallets w
LEFT JOIN transactions t 
  ON (t.wallet_id = w.id OR t.to_wallet_id = w.id) 
  AND t.deleted_at IS NULL
WHERE w.is_archived = 0
GROUP BY w.id
ORDER BY w.sort_order ASC, w.id ASC;
```

### 2.7 High-Performance Keyset Pagination
Instead of inefficient `OFFSET` queries that degrade as transaction count grows, history is queried using keyset pagination:
```sql
SELECT t.*, c.name as category_name, c.emoji as category_emoji
FROM transactions t
LEFT JOIN categories c ON c.id = t.category_id
WHERE t.deleted_at IS NULL
  AND (
    ? IS NULL OR 
    (t.occurred_date < ?) OR 
    (t.occurred_date = ? AND t.occurred_time < ?) OR 
    (t.occurred_date = ? AND t.occurred_time = ? AND t.id < ?)
  )
ORDER BY t.occurred_date DESC, t.occurred_time DESC, t.id DESC
LIMIT ?;
```

### 2.8 Default Amount Fallback
- `categories.default_amount_cents`: Default amount for that category, prefilling the transaction amount.
- `reminder_slots.default_amount_cents`: Nullable column.
  - When `NULL`: Dynamically falls back to `category.default_amount_cents`.
  - When non-null: Uses the reminder slot's customized override amount.

### 2.9 Atomic Clear All Data
- `clearAllLedgerData()` runs in a single transaction executing `DELETE FROM transactions;`.
- Wallets, categories, reminder slots, and app settings remain intact.
- Post-clear wallet balances strictly equal their configured `opening_balance_cents`.

### 2.10 Centralized App Settings (`app_settings`)
- Replaces loose `SharedPreferences` keys (`daily_budget`, `snooze_duration_minutes`, `wallet_setup_done`) with a transactional key-value table directly in SQLite.

---

## 3. Database File Backup Advice
Before performing manual migrations or schema resets on a device or emulator with existing testing data, copy the database file to a safe location:

```bash
# Android (Debug / Run-as)
adb shell "run-as com.example.money_management_app cp /data/data/com.example.money_management_app/databases/vault_money.db /sdcard/Download/vault_money_backup.db"
adb pull /sdcard/Download/vault_money_backup.db ./vault_money_backup.db

# Windows / Desktop testing
copy "$env:LOCALAPPDATA\com.example.money_management_app\vault_money.db" ".\vault_money_backup.db"
```
