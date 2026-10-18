abstract class WalletFailure implements Exception {
  final String message;
  const WalletFailure(this.message);

  @override
  String toString() => message;
}

class WalletNameTakenFailure extends WalletFailure {
  const WalletNameTakenFailure([super.message = "A wallet with this name already exists."]);
}

class WalletLimitReachedFailure extends WalletFailure {
  const WalletLimitReachedFailure([super.message = "You can only have up to 10 active wallets."]);
}

class LastWalletFailure extends WalletFailure {
  const LastWalletFailure([super.message = "You need at least one wallet."]);
}

class WalletNotFoundFailure extends WalletFailure {
  const WalletNotFoundFailure([super.message = "The selected wallet was not found."]);
}

class WalletHasBalanceFailure extends WalletFailure {
  const WalletHasBalanceFailure([super.message = "Wallet balance must be moved before removing."]);
}

class DatabaseFailure extends WalletFailure {
  const DatabaseFailure([super.message = "An error occurred while updating the database."]);
}
