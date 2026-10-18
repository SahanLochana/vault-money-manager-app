import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/failures/wallet_failure.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletRepository walletRepository;
  final ExpenseRepository? expenseRepository;

  WalletBloc({
    required this.walletRepository,
    this.expenseRepository,
  }) : super(const WalletInitial()) {
    on<LoadWalletsEvent>(_onLoadWallets);
    on<AddWalletEvent>(_onAddWallet);
    on<UpdateWalletEvent>(_onUpdateWallet);
    on<RemoveWalletEvent>(_onRemoveWallet);
    on<RestoreWalletEvent>(_onRestoreWallet);
    on<AddWalletFundsEvent>(_onAddWalletFunds);
    on<DeleteWalletFundEvent>(_onDeleteWalletFund);
    on<RestoreWalletFundEvent>(_onRestoreWalletFund);
    on<AddWalletTransferEvent>(_onAddWalletTransfer);
    on<DeleteWalletTransferEvent>(_onDeleteWalletTransfer);
    on<RestoreWalletTransferEvent>(_onRestoreWalletTransfer);
  }

  Future<void> _reloadWallets(
    Emitter<WalletState> emit, {
    String? successMessage,
    int? lastArchivedWalletId,
  }) async {
    final wallets = await walletRepository.getAllWallets();
    final Map<int, double> balances = {
      for (final w in wallets) w.id: w.balance,
    };
    final Map<int, double> fundTotals = {
      for (final w in wallets) w.id: w.totalFunds,
    };
    final Map<int, double> expenseTotals = {
      for (final w in wallets) w.id: w.totalSpent,
    };

    emit(
      WalletLoaded(
        wallets: wallets,
        balances: balances,
        totalFunds: fundTotals,
        totalSpent: expenseTotals,
        successMessage: successMessage,
        lastArchivedWalletId: lastArchivedWalletId,
      ),
    );
  }

  void _emitError(Emitter<WalletState> emit, String message) {
    if (state is WalletLoaded) {
      emit((state as WalletLoaded).copyWith(
        actionError: message,
        clearActionMessages: false,
      ));
    } else {
      emit(WalletError(message));
    }
  }

  Future<void> _onLoadWallets(
    LoadWalletsEvent event,
    Emitter<WalletState> emit,
  ) async {
    if (state is! WalletLoaded) {
      emit(const WalletLoading());
    }
    try {
      await _reloadWallets(emit);
    } catch (e) {
      if (state is WalletLoaded) {
        emit((state as WalletLoaded).copyWith(
          actionError: "Failed to refresh wallets.",
        ));
      } else {
        emit(const WalletError("Unable to load wallets. Tap to retry."));
      }
    }
  }

  Future<void> _onAddWallet(
    AddWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final name = event.wallet.name.trim();
      if (name.isEmpty || name.length > 24) {
        _emitError(emit, "Wallet name must be between 1 and 24 characters.");
        return;
      }
      await walletRepository.addWallet(event.wallet);
      await _reloadWallets(emit, successMessage: "Wallet '$name' created.");
    } on WalletFailure catch (f) {
      _emitError(emit, f.message);
    } catch (_) {
      _emitError(emit, "Failed to create wallet. Please try again.");
    }
  }

  Future<void> _onUpdateWallet(
    UpdateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final name = event.wallet.name.trim();
      if (name.isEmpty || name.length > 24) {
        _emitError(emit, "Wallet name must be between 1 and 24 characters.");
        return;
      }
      await walletRepository.updateWallet(event.wallet);
      await _reloadWallets(emit, successMessage: "Wallet '$name' updated.");
    } on WalletFailure catch (f) {
      _emitError(emit, f.message);
    } catch (_) {
      _emitError(emit, "Failed to update wallet. Please try again.");
    }
  }

  Future<void> _onRemoveWallet(
    RemoveWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final active = await walletRepository.getAllWallets(includeArchived: false);
      if (active.length <= 1) {
        _emitError(emit, const LastWalletFailure().message);
        return;
      }

      final wallet = active.where((w) => w.id == event.walletId).firstOrNull;
      if (wallet == null) {
        _emitError(emit, const WalletNotFoundFailure().message);
        return;
      }

      final balanceCents = wallet.balanceCents ?? wallet.openingBalanceCents;

      if (balanceCents != 0) {
        if (event.transferToWalletId == null) {
          _emitError(emit, const WalletHasBalanceFailure().message);
          return;
        }

        await walletRepository.transferBalanceAndArchive(
          fromWalletId: wallet.id,
          toWalletId: event.transferToWalletId!,
          balanceCents: balanceCents,
          note: event.note,
        );

        await _reloadWallets(
          emit,
          successMessage: "Wallet '${wallet.name}' archived. Remaining balance moved.",
          lastArchivedWalletId: wallet.id,
        );
      } else {
        final hasHistory = await walletRepository.hasHistory(wallet.id);
        if (hasHistory) {
          await walletRepository.archiveWallet(wallet.id);
          await _reloadWallets(
            emit,
            successMessage: "Wallet '${wallet.name}' archived.",
            lastArchivedWalletId: wallet.id,
          );
        } else {
          await walletRepository.deleteWalletPermanently(wallet.id);
          await _reloadWallets(
            emit,
            successMessage: "Wallet '${wallet.name}' permanently deleted.",
            lastArchivedWalletId: null,
          );
        }
      }
    } on WalletFailure catch (f) {
      _emitError(emit, f.message);
    } catch (_) {
      _emitError(emit, "Failed to remove wallet. Please try again.");
    }
  }

  Future<void> _onRestoreWallet(
    RestoreWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.restoreWallet(event.walletId);
      await _reloadWallets(
        emit,
        successMessage: "Wallet restored successfully.",
      );
    } on WalletFailure catch (f) {
      _emitError(emit, f.message);
    } catch (_) {
      _emitError(emit, "Failed to restore wallet. Please try again.");
    }
  }

  Future<void> _onAddWalletFunds(
    AddWalletFundsEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.addFunds(event.fund);
      await _reloadWallets(
        emit,
        successMessage: "Funds added successfully.",
      );
    } catch (_) {
      _emitError(emit, "Failed to add funds. Please try again.");
    }
  }

  Future<void> _onDeleteWalletFund(
    DeleteWalletFundEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.deleteFund(event.fundId);
      await _reloadWallets(emit);
    } catch (_) {
      _emitError(emit, "Failed to delete fund.");
    }
  }

  Future<void> _onRestoreWalletFund(
    RestoreWalletFundEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.restoreFund(event.fundId);
      await _reloadWallets(emit);
    } catch (_) {
      _emitError(emit, "Failed to restore fund.");
    }
  }

  Future<void> _onAddWalletTransfer(
    AddWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.addTransfer(event.transfer);
      await _reloadWallets(emit);
    } catch (_) {
      _emitError(emit, "Failed to add transfer.");
    }
  }

  Future<void> _onDeleteWalletTransfer(
    DeleteWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.softDeleteTransfer(event.transferId);
      await _reloadWallets(emit);
    } catch (_) {
      _emitError(emit, "Failed to delete transfer.");
    }
  }

  Future<void> _onRestoreWalletTransfer(
    RestoreWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.restoreTransfer(event.transferId);
      await _reloadWallets(emit);
    } catch (_) {
      _emitError(emit, "Failed to restore transfer.");
    }
  }
}
