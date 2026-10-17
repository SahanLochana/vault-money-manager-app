import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';

abstract class TransactionRepository {
  Future<int> addTransaction(TransactionItem item);
  Future<void> updateTransaction(TransactionItem item);
  Future<void> softDeleteTransaction(int id);
  Future<void> restoreTransaction(int id);
  Future<TransactionItem?> getTransactionById(int id);
  Future<List<TransactionItem>> getTodayTransactions({String? type});
  Future<List<TransactionItem>> getTransactionsForMonth(int year, int month, {String? type});
  Future<List<TransactionItem>> getPaginatedTransactions({
    int limit = 30,
    String? cursorDate,
    String? cursorTime,
    int? cursorId,
    int? walletId,
    String? type,
  });
  Future<MonthlyStatsResult> getMonthlyStats(int year, int month);
  Future<int> clearAllLedgerData();
  Future<Map<String, dynamic>> exportAllData();
  Future<List<Map<String, dynamic>>> exportAllTransactions();
}
