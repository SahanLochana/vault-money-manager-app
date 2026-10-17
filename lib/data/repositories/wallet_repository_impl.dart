import 'package:money_management_app/data/datasources/wallet_local_datasource.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletLocalDatasource localDatasource;

  WalletRepositoryImpl({required this.localDatasource});

  @override
  Future<List<Wallet>> getAllWallets({bool includeArchived = false}) async {
    return await localDatasource.getAllWallets(includeArchived: includeArchived);
  }

  @override
  Future<Wallet?> getWalletById(int id) async {
    return await localDatasource.getWalletById(id);
  }

  @override
  Future<int> addWallet(Wallet wallet) async {
    return await localDatasource.insertWallet(wallet);
  }

  @override
  Future<void> updateWallet(Wallet wallet) async {
    await localDatasource.updateWallet(wallet);
  }

  @override
  Future<int> addFunds(WalletFund fund) async {
    return await localDatasource.insertWalletFund(fund.toMap());
  }

  @override
  Future<List<WalletFund>> getFundsForWallet(int walletId) async {
    final list = await localDatasource.getFundsForWallet(walletId);
    return list.map((e) => WalletFund.fromMap(e)).toList();
  }

  @override
  Future<Map<int, double>> getAllWalletFundTotals() async {
    final map = await localDatasource.getAllWalletFundTotalsCents();
    return map.map((key, value) => MapEntry(key, value / 100.0));
  }

  @override
  Future<void> deleteFund(int id) async {
    await localDatasource.deleteWalletFund(id);
  }

  @override
  Future<void> restoreFund(int id) async {
    await localDatasource.restoreWalletFund(id);
  }

  @override
  Future<int> addTransfer(WalletTransfer transfer) async {
    return await localDatasource.insertWalletTransfer(transfer.toMap());
  }

  @override
  Future<void> softDeleteTransfer(int id) async {
    await localDatasource.softDeleteTransfer(id);
  }

  @override
  Future<void> restoreTransfer(int id) async {
    await localDatasource.restoreTransfer(id);
  }

  @override
  Future<List<WalletTransfer>> getTodayTransfers() async {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final list = await localDatasource.getTodayTransfers(todayStr);
    return list.map((e) => WalletTransfer.fromMap(e)).toList();
  }

  @override
  Future<List<WalletTransfer>> getAllActiveTransfers() async {
    final list = await localDatasource.getAllActiveTransfers();
    return list.map((e) => WalletTransfer.fromMap(e)).toList();
  }

  @override
  Future<Map<String, List<WalletTransfer>>> getTransfersGroupedByDate() async {
    final transfers = await getAllActiveTransfers();
    final Map<String, List<WalletTransfer>> grouped = {};
    for (final t in transfers) {
      if (!grouped.containsKey(t.transferDate)) {
        grouped[t.transferDate] = [];
      }
      grouped[t.transferDate]!.add(t);
    }
    return grouped;
  }

  @override
  Future<Map<int, double>> getTransferInTotals() async {
    final map = await localDatasource.getTransferInTotalsCents();
    return map.map((key, value) => MapEntry(key, value / 100.0));
  }

  @override
  Future<Map<int, double>> getTransferOutTotals() async {
    final map = await localDatasource.getTransferOutTotalsCents();
    return map.map((key, value) => MapEntry(key, value / 100.0));
  }
}
