import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<AddWalletFundsEvent>(_onAddWalletFunds);
    on<DeleteWalletFundEvent>(_onDeleteWalletFund);
    on<RestoreWalletFundEvent>(_onRestoreWalletFund);
    on<AddWalletTransferEvent>(_onAddWalletTransfer);
    on<DeleteWalletTransferEvent>(_onDeleteWalletTransfer);
    on<RestoreWalletTransferEvent>(_onRestoreWalletTransfer);
    on<UpdateWalletEvent>(_onUpdateWallet);
  }

  Future<void> _onLoadWallets(
    LoadWalletsEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    try {
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
        ),
      );
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onAddWalletFunds(
    AddWalletFundsEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.addFunds(event.fund);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onDeleteWalletFund(
    DeleteWalletFundEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.deleteFund(event.fundId);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onRestoreWalletFund(
    RestoreWalletFundEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.restoreFund(event.fundId);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onAddWalletTransfer(
    AddWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.addTransfer(event.transfer);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onDeleteWalletTransfer(
    DeleteWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.softDeleteTransfer(event.transferId);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onRestoreWalletTransfer(
    RestoreWalletTransferEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.restoreTransfer(event.transferId);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onUpdateWallet(
    UpdateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await walletRepository.updateWallet(event.wallet);
      add(const LoadWalletsEvent());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }
}
