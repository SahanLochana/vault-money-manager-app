import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/add_funds_dialog.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/pill_action_button.dart';
import 'package:money_management_app/presentation/widgets/remove_wallet_dialog.dart';
import 'package:money_management_app/presentation/widgets/total_balance_card.dart';
import 'package:money_management_app/presentation/widgets/wallet_card.dart';
import 'package:money_management_app/presentation/widgets/wallet_form_dialog.dart';

class ManageWalletsPage extends StatefulWidget {
  const ManageWalletsPage({super.key});

  @override
  State<ManageWalletsPage> createState() => _ManageWalletsPageState();
}

class _ManageWalletsPageState extends State<ManageWalletsPage> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const LoadWalletsEvent());
  }

  Future<void> _openAddWalletDialog(List<Wallet> wallets) async {
    if (wallets.length >= 10) {
      AppSnackBar.show(
        context,
        message: "You can only have up to 10 active wallets.",
        isError: true,
      );
      return;
    }

    final newWallet = await WalletFormDialog.show(
      context,
      existingWallets: wallets,
    );

    if (newWallet != null && mounted) {
      context.read<WalletBloc>().add(AddWalletEvent(newWallet));
    }
  }

  Future<void> _openEditWalletDialog(Wallet wallet, List<Wallet> wallets) async {
    final updated = await WalletFormDialog.show(
      context,
      walletToEdit: wallet,
      existingWallets: wallets,
    );

    if (updated != null && mounted) {
      context.read<WalletBloc>().add(UpdateWalletEvent(updated));
    }
  }

  Future<void> _openAddFundsDialog(List<Wallet> wallets, {Wallet? preselected}) async {
    if (wallets.isEmpty) {
      AppSnackBar.show(
        context,
        message: "Create a wallet first before adding funds.",
        isError: true,
      );
      return;
    }

    final fund = await AddFundsDialog.show(
      context,
      wallets: wallets,
      preselectedWallet: preselected,
    );

    if (fund != null && mounted) {
      context.read<WalletBloc>().add(AddWalletFundsEvent(fund));
    }
  }

  Future<void> _handleRemoveWallet(Wallet wallet, List<Wallet> wallets) async {
    if (wallets.length <= 1) {
      AppSnackBar.show(
        context,
        message: "You need at least one wallet.",
        isError: true,
      );
      return;
    }

    final otherWallets = wallets.where((w) => w.id != wallet.id).toList();
    final balanceCents = wallet.balanceCents ?? wallet.openingBalanceCents;

    // 1. Non-zero balance: Prompt user to choose target wallet to move balance
    if (balanceCents != 0) {
      final targetWalletId = await RemoveWalletDialog.showMoveBalanceDialog(
        context,
        walletToRemove: wallet,
        otherWallets: otherWallets,
      );

      if (targetWalletId != null && mounted) {
        context.read<WalletBloc>().add(
              RemoveWalletEvent(
                walletId: wallet.id,
                transferToWalletId: targetWalletId,
              ),
            );
      }
      return;
    }

    // 2. Zero balance: Check if wallet has transaction history
    final repo = context.read<WalletRepository>();
    final hasHistory = await repo.hasHistory(wallet.id);

    if (!mounted) return;

    if (hasHistory) {
      final confirmed = await RemoveWalletDialog.confirmArchive(
        context,
        wallet: wallet,
      );
      if (confirmed && mounted) {
        context.read<WalletBloc>().add(RemoveWalletEvent(walletId: wallet.id));
      }
    } else {
      final confirmed = await RemoveWalletDialog.confirmPermanentDelete(
        context,
        wallet: wallet,
      );
      if (confirmed && mounted) {
        context.read<WalletBloc>().add(RemoveWalletEvent(walletId: wallet.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBackAppBar(
        title: "Wallets",
        actions: [
          BlocBuilder<WalletBloc, WalletState>(
            builder: (context, state) {
              final wallets = (state is WalletLoaded) ? state.wallets : <Wallet>[];
              final isCompact = MediaQuery.sizeOf(context).width < 360 ||
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.2;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCompact)
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      tooltip: "Add Wallet",
                      onPressed: () => _openAddWalletDialog(wallets),
                    )
                  else
                    PillActionButton(
                      label: "Add Wallet",
                      icon: Icons.add_rounded,
                      color: AppColors.primary,
                      onPressed: () => _openAddWalletDialog(wallets),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_card_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    tooltip: "Add Funds",
                    onPressed: () => _openAddFundsDialog(wallets),
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is WalletLoaded) {
            if (state.actionError != null) {
              AppSnackBar.show(
                context,
                message: state.actionError!,
                isError: true,
              );
            } else if (state.successMessage != null) {
              context.read<ExpenseBloc>().add(const LoadExpenses());
              if (state.lastArchivedWalletId != null) {
                AppSnackBar.show(
                  context,
                  message: state.successMessage!,
                  actionLabel: "Undo",
                  onAction: () {
                    context
                        .read<WalletBloc>()
                        .add(RestoreWalletEvent(state.lastArchivedWalletId!));
                  },
                );
              } else {
                AppSnackBar.show(context, message: state.successMessage!);
              }
            }
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) {
            return const AppLoadingIndicator();
          }

          if (state is WalletError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: AppColors.expense,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<WalletBloc>().add(const LoadWalletsEvent());
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text("Retry"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF0F0F14),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is WalletLoaded) {
            if (state.wallets.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 34,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "No Wallets Found",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Create your first wallet to track accounts, cash, and balances.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _openAddWalletDialog(state.wallets),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("Create Wallet"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF0F0F14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    context.read<WalletBloc>().add(const LoadWalletsEvent());
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    children: [
                      TotalBalanceCard(
                        totalBalance: state.grandTotalBalance,
                        wallets: state.wallets,
                        balances: state.balances,
                      ),
                      ...state.wallets.map((wallet) {
                        final balance = state.getBalance(wallet.id);
                        final totalFunds = state.getTotalFund(wallet.id);
                        final totalSpent = state.getTotalSpent(wallet.id);

                        return WalletCard(
                          key: ValueKey(wallet.id),
                          wallet: wallet,
                          balance: balance,
                          totalFunds: totalFunds,
                          totalSpent: totalSpent,
                          onEdit: () => _openEditWalletDialog(wallet, state.wallets),
                          onAddFunds: () => _openAddFundsDialog(
                            state.wallets,
                            preselected: wallet,
                          ),
                          onRemove: () => _handleRemoveWallet(wallet, state.wallets),
                        );
                      }),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
