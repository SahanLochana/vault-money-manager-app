import 'package:money_management_app/domain/models/wallet.dart';

abstract class WalletState {
  const WalletState();
}

class WalletInitial extends WalletState {
  const WalletInitial();
}

class WalletLoading extends WalletState {
  const WalletLoading();
}

class WalletLoaded extends WalletState {
  final List<Wallet> wallets;
  final Map<int, double> balances;
  final Map<int, double> totalFunds;
  final Map<int, double> totalSpent;

  final String? actionError;
  final String? successMessage;
  final int? lastArchivedWalletId;

  const WalletLoaded({
    required this.wallets,
    required this.balances,
    required this.totalFunds,
    required this.totalSpent,
    this.actionError,
    this.successMessage,
    this.lastArchivedWalletId,
  });

  double getBalance(int walletId) => balances[walletId] ?? 0.0;
  double getTotalFund(int walletId) => totalFunds[walletId] ?? 0.0;
  double getTotalSpent(int walletId) => totalSpent[walletId] ?? 0.0;

  double get grandTotalBalance {
    double sum = 0;
    for (final b in balances.values) {
      sum += b;
    }
    return sum;
  }

  WalletLoaded copyWith({
    List<Wallet>? wallets,
    Map<int, double>? balances,
    Map<int, double>? totalFunds,
    Map<int, double>? totalSpent,
    String? actionError,
    String? successMessage,
    int? lastArchivedWalletId,
    bool clearActionMessages = false,
  }) {
    return WalletLoaded(
      wallets: wallets ?? this.wallets,
      balances: balances ?? this.balances,
      totalFunds: totalFunds ?? this.totalFunds,
      totalSpent: totalSpent ?? this.totalSpent,
      actionError: clearActionMessages ? null : (actionError ?? this.actionError),
      successMessage: clearActionMessages ? null : (successMessage ?? this.successMessage),
      lastArchivedWalletId: clearActionMessages ? null : (lastArchivedWalletId ?? this.lastArchivedWalletId),
    );
  }
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);
}
