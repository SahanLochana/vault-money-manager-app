import 'package:money_management_app/data/datasources/wallet_local_datasource.dart';
import 'package:money_management_app/domain/failures/wallet_failure.dart';
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
    final activeWallets = await localDatasource.getAllWallets(includeArchived: false);
    if (activeWallets.length >= 10) {
      throw const WalletLimitReachedFailure();
    }

    final trimmedName = wallet.name.trim();
    final nameLower = trimmedName.toLowerCase();
    final nameExists = activeWallets.any((w) => w.name.trim().toLowerCase() == nameLower);
    if (nameExists) {
      throw const WalletNameTakenFailure();
    }

    final nextOrder = await localDatasource.getNextSortOrder();
    final walletToInsert = wallet.copyWith(
      name: trimmedName,
      sortOrder: wallet.sortOrder != 0 ? wallet.sortOrder : nextOrder,
    );
    return await localDatasource.insertWallet(walletToInsert);
  }

  @override
  Future<void> updateWallet(Wallet wallet) async {
    final trimmedName = wallet.name.trim();
    final nameLower = trimmedName.toLowerCase();
    final activeWallets = await localDatasource.getAllWallets(includeArchived: false);
    final nameExists = activeWallets.any(
      (w) => w.id != wallet.id && w.name.trim().toLowerCase() == nameLower,
    );
    if (nameExists) {
      throw const WalletNameTakenFailure();
    }
    await localDatasource.updateWallet(wallet.copyWith(name: trimmedName));
  }

  @override
  Future<bool> hasHistory(int walletId) async {
    return await localDatasource.hasHistory(walletId);
  }

  @override
  Future<void> deleteWalletPermanently(int walletId) async {
    await localDatasource.deleteWalletPermanently(walletId);
  }

  @override
  Future<void> archiveWallet(int walletId) async {
    await localDatasource.archiveWallet(walletId);
  }

  @override
  Future<void> restoreWallet(int walletId) async {
    await localDatasource.restoreWallet(walletId);
  }

  @override
  Future<void> transferBalanceAndArchive({
    required int fromWalletId,
    required int toWalletId,
    required int balanceCents,
    String? note,
  }) async {
    await localDatasource.transferBalanceAndArchive(
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      balanceCents: balanceCents,
      note: note,
    );
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
