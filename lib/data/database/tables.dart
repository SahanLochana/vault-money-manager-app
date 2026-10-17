class AppTables {
  // Table names
  static const String wallets = 'wallets';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String reminderSlots = 'reminder_slots';
  static const String appSettings = 'app_settings';

  // Wallets Columns
  static const String colWalletId = 'id';
  static const String colWalletName = 'name';
  static const String colWalletEmoji = 'emoji';
  static const String colWalletOpeningBalanceCents = 'opening_balance_cents';
  static const String colWalletSortOrder = 'sort_order';
  static const String colWalletIsArchived = 'is_archived';
  static const String colWalletCreatedAt = 'created_at';

  // Categories Columns
  static const String colCatId = 'id';
  static const String colCatKind = 'kind'; // 'expense' or 'income'
  static const String colCatName = 'name';
  static const String colCatEmoji = 'emoji';
  static const String colCatDefaultAmountCents = 'default_amount_cents';
  static const String colCatSortOrder = 'sort_order';
  static const String colCatDeletedAt = 'deleted_at'; // NULL if active
  static const String colCatCreatedAt = 'created_at';

  // Transactions (Single Ledger) Columns
  static const String colTxId = 'id';
  static const String colTxType = 'type'; // 'expense', 'income', or 'transfer'
  static const String colTxAmountCents = 'amount_cents';
  static const String colTxWalletId = 'wallet_id'; // source or receiving wallet
  static const String colTxToWalletId = 'to_wallet_id'; // transfers only
  static const String colTxCategoryId = 'category_id'; // NULL for transfers & uncategorized
  static const String colTxOccurredDate = 'occurred_date'; // YYYY-MM-DD
  static const String colTxOccurredTime = 'occurred_time'; // HH:mm
  static const String colTxNote = 'note';
  static const String colTxDeletedAt = 'deleted_at'; // NULL if active
  static const String colTxCreatedAt = 'created_at';
  static const String colTxUpdatedAt = 'updated_at';

  // Reminder Slots Columns
  static const String colReminderId = 'id';
  static const String colReminderCategoryId = 'category_id';
  static const String colReminderTime = 'time'; // HH:mm
  static const String colReminderDefaultAmountCents = 'default_amount_cents'; // NULL = fallback to category default
  static const String colReminderIsActive = 'is_active'; // 0 or 1

  // App Settings Columns
  static const String colSettingKey = 'key';
  static const String colSettingValue = 'value';

  // Legacy aliases for backwards compatibility with any remaining code
  static const String expenses = transactions;
  static const String colExpenseId = colTxId;
  static const String colExpenseCategoryId = colTxCategoryId;
  static const String colExpenseAmountCents = colTxAmountCents;
  static const String colExpenseWalletId = colTxWalletId;
  static const String colExpenseDate = colTxOccurredDate;
  static const String colExpenseTime = colTxOccurredTime;
  static const String colExpenseNote = colTxNote;
  static const String colExpenseIsDeleted = 'is_deleted';
  static const String colExpenseCreatedAt = colTxCreatedAt;
  static const String colExpenseUpdatedAt = colTxUpdatedAt;

  static const String walletFunds = 'wallet_funds';
  static const String colFundId = 'id';
  static const String colFundWalletId = 'wallet_id';
  static const String colFundAmountCents = 'amount_cents';
  static const String colFundNote = 'note';
  static const String colFundCreatedAt = 'created_at';

  static const String walletTransfers = 'wallet_transfers';
  static const String colTransferId = 'id';
  static const String colTransferFromWalletId = 'from_wallet_id';
  static const String colTransferToWalletId = 'to_wallet_id';
  static const String colTransferAmountCents = 'amount_cents';
  static const String colTransferDate = 'transfer_date';
  static const String colTransferTime = 'transfer_time';
  static const String colTransferNote = 'note';
  static const String colTransferIsDeleted = 'is_deleted';
  static const String colTransferCreatedAt = 'created_at';

  static const String colCatIsSystem = 'is_system';
  static const String colCatIsDeleted = 'is_deleted';
  static const String colReminderIsSystem = 'is_system';
}
