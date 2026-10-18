import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';

abstract class WalletRepository {
  Future<List<Wallet>> getAllWallets({bool includeArchived = false});
  Future<Wallet?> getWalletById(int id);
  Future<int> addWallet(Wallet wallet);
  Future<void> updateWallet(Wallet wallet);
  Future<int> addFunds(WalletFund fund);
  Future<List<WalletFund>> getFundsForWallet(int walletId);
  Future<Map<int, double>> getAllWalletFundTotals();
  Future<void> deleteFund(int id);
  Future<void> restoreFund(int id);

  Future<bool> hasHistory(int walletId);
  Future<void> deleteWalletPermanently(int walletId);
  Future<void> archiveWallet(int walletId);
  Future<void> restoreWallet(int walletId);
  Future<void> transferBalanceAndArchive({
    required int fromWalletId,
    required int toWalletId,
    required int balanceCents,
    String? note,
  });

  // Transfers
  Future<int> addTransfer(WalletTransfer transfer);
  Future<void> softDeleteTransfer(int id);
  Future<void> restoreTransfer(int id);
  Future<List<WalletTransfer>> getTodayTransfers();
  Future<List<WalletTransfer>> getAllActiveTransfers();
  Future<Map<String, List<WalletTransfer>>> getTransfersGroupedByDate();
  Future<Map<int, double>> getTransferInTotals();
  Future<Map<int, double>> getTransferOutTotals();
}
