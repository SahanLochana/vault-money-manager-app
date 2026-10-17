import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/domain/models/transaction_item.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDatasource localDatasource;

  TransactionRepositoryImpl({required this.localDatasource});

  @override
  Future<int> addTransaction(TransactionItem item) async {
    return await localDatasource.insertTransaction(item);
  }

  @override
  Future<void> updateTransaction(TransactionItem item) async {
    await localDatasource.updateTransaction(item);
  }

  @override
  Future<void> softDeleteTransaction(int id) async {
    await localDatasource.softDeleteTransaction(id);
  }

  @override
  Future<void> restoreTransaction(int id) async {
    await localDatasource.restoreTransaction(id);
  }

  @override
  Future<TransactionItem?> getTransactionById(int id) async {
    return await localDatasource.getTransactionById(id);
  }

  @override
  Future<List<TransactionItem>> getTodayTransactions({String? type}) async {
    return await localDatasource.getTodayTransactions(type: type);
  }

  @override
  Future<List<TransactionItem>> getTransactionsForMonth(int year, int month, {String? type}) async {
    return await localDatasource.getTransactionsForMonth(year, month, type: type);
  }

  @override
  Future<List<TransactionItem>> getPaginatedTransactions({
    int limit = 30,
    String? cursorDate,
    String? cursorTime,
    int? cursorId,
    int? walletId,
    String? type,
  }) async {
    return await localDatasource.getPaginatedTransactions(
      limit: limit,
      cursorDate: cursorDate,
      cursorTime: cursorTime,
      cursorId: cursorId,
      walletId: walletId,
      type: type,
    );
  }

  @override
  Future<MonthlyStatsResult> getMonthlyStats(int year, int month) async {
    return await localDatasource.getMonthlyStats(year, month);
  }

  @override
  Future<int> clearAllLedgerData() async {
    return await localDatasource.clearAllLedgerData();
  }

  @override
  Future<Map<String, dynamic>> exportAllData() async {
    return await localDatasource.exportAllData();
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllTransactions() async {
    return await localDatasource.exportAllTransactions();
  }
}
