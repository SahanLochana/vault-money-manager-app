import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/models/wallet_transfer.dart';

abstract class WalletEvent {
  const WalletEvent();
}

class LoadWalletsEvent extends WalletEvent {
  const LoadWalletsEvent();
}

class AddWalletFundsEvent extends WalletEvent {
  final WalletFund fund;
  const AddWalletFundsEvent(this.fund);
}

class DeleteWalletFundEvent extends WalletEvent {
  final int fundId;
  const DeleteWalletFundEvent(this.fundId);
}

class RestoreWalletFundEvent extends WalletEvent {
  final int fundId;
  const RestoreWalletFundEvent(this.fundId);
}

class AddWalletTransferEvent extends WalletEvent {
  final WalletTransfer transfer;
  const AddWalletTransferEvent(this.transfer);
}

class DeleteWalletTransferEvent extends WalletEvent {
  final int transferId;
  const DeleteWalletTransferEvent(this.transferId);
}

class RestoreWalletTransferEvent extends WalletEvent {
  final int transferId;
  const RestoreWalletTransferEvent(this.transferId);
}

class UpdateWalletEvent extends WalletEvent {
  final Wallet wallet;
  const UpdateWalletEvent(this.wallet);
}

