import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_state.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';
import 'package:money_management_app/presentation/screens/add_transaction_page.dart';
import 'package:money_management_app/presentation/screens/manage_wallets_page.dart';
import 'package:money_management_app/presentation/screens/settings_page.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';
import 'package:money_management_app/presentation/widgets/herocard.dart';
import 'package:money_management_app/presentation/widgets/section_header.dart';
import 'package:money_management_app/presentation/widgets/transaction_details_sheet.dart';
import 'package:money_management_app/presentation/widgets/transactioncard.dart';

class Homepage extends StatelessWidget {
  const Homepage({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning 👋";
    } else if (hour < 17) {
      return "Good Afternoon 👋";
    } else {
      return "Good Evening 👋";
    }
  }

  void _deleteTransaction(BuildContext context, LedgerTransaction tx) {
    if (tx.id == null) return;
    final txId = tx.id!;
    context.read<ExpenseBloc>().add(DeleteExpenseEvent(txId));

    String actionMsg;
    if (tx is TransferTransaction) {
      actionMsg = "Reverted transfer (${tx.formattedAmount})";
    } else if (tx is IncomeTransaction) {
      actionMsg = "Deleted income (${tx.formattedAmount})";
    } else {
      actionMsg =
          "Deleted expense (${tx.formattedAmount}) • Restored to wallet";
    }

    AppSnackBar.show(
      context,
      message: actionMsg,
      actionLabel: "Undo",
      durationSeconds: 3,
      onAction: () {
        context.read<ExpenseBloc>().add(RestoreExpenseEvent(txId));
      },
    );
  }

  Future<bool> _confirmDeleteDialog(
    BuildContext context,
    LedgerTransaction tx,
    Wallet? wallet,
    Wallet? toWallet,
  ) async {
    if (tx is TransferTransaction) {
      final fromName = wallet?.name ?? "source wallet";
      final toName = toWallet?.name ?? "destination wallet";
      return ConfirmActionDialog.show(
        context,
        title: "Revert Transfer?",
        message:
            "Are you sure you want to revert this transfer (${tx.formattedAmount})? This will return ${tx.formattedAmount} to $fromName and deduct it from $toName.",
        confirmLabel: "Revert",
        confirmColor: AppColors.expense,
      );
    } else if (tx is IncomeTransaction) {
      return ConfirmActionDialog.show(
        context,
        title: "Delete Income?",
        message:
            "Are you sure you want to delete this income (${tx.formattedAmount})? This will deduct ${tx.formattedAmount} from ${wallet?.name ?? 'your wallet'}.",
        confirmLabel: "Delete",
        confirmColor: AppColors.expense,
      );
    } else {
      return ConfirmActionDialog.show(
        context,
        title: "Delete Expense?",
        message:
            "Are you sure you want to delete this expense (${tx.formattedAmount})? This will restore ${tx.formattedAmount} back to your wallet balance.",
        confirmLabel: "Delete",
        confirmColor: AppColors.expense,
      );
    }
  }

  void _editTransaction(BuildContext context, LedgerTransaction tx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AddTransactionPage(transactionToEdit: tx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMM').format(now);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        centerTitle: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              formattedDate,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
              onPressed: () {
                final expenseBloc = context.read<ExpenseBloc>();
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    )
                    .then((_) {
                      expenseBloc.add(const LoadExpenses());
                    });
              },
            ),
          ),
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const AppLoadingIndicator();
          }

          if (state is ExpenseError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: AppColors.expense),
              ),
            );
          }

          List<LedgerTransaction> todayTransactions = [];
          double todaySpent = 0.0;
          double dailyBudget = 500.0;

          if (state is ExpenseLoaded) {
            todayTransactions = state.todayTransactions;
            todaySpent = state.todayTotal;
            dailyBudget = state.dailyBudget;
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              context.read<ExpenseBloc>().add(const LoadExpenses());
              context.read<WalletBloc>().add(const LoadWalletsEvent());
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Hero Card: Today's Spend + Daily Budget Remaining (Transfers excluded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: TodaySpentCard(
                      dailySpent: todaySpent,
                      dailyBudget: dailyBudget,
                    ),
                  ),
                ),

                // Live Wallet Balance Chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: BlocBuilder<WalletBloc, WalletState>(
                      builder: (context, walletState) {
                        if (walletState is WalletLoaded) {
                          return Row(
                            children: walletState.wallets.map((wallet) {
                              final balance = walletState.getBalance(wallet.id);
                              final isNegative = balance < 0;

                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: wallet == walletState.wallets.last
                                        ? 0
                                        : 10,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ManageWalletsPage(),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isNegative
                                                ? AppColors.expense.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : AppColors.surfaceBorder
                                                      .withValues(alpha: 0.7),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              wallet.emoji,
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    wallet.name,
                                                    style: const TextStyle(
                                                      color: AppColors
                                                          .textSecondary,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    "Rs ${balance.toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                      color: isNegative
                                                          ? AppColors.expense
                                                          : AppColors
                                                                .textPrimary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),

                // Section Header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: SectionHeader(title: "Today's Transactions"),
                  ),
                ),

                // Today's Activity List or Empty State
                if (todayTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceBorder,
                                ),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: AppColors.textMuted,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "No transactions today",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tap the + button to add an expense, income or transfer",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final tx = todayTransactions[index];
                        Category? category;
                        Wallet? wallet;
                        Wallet? toWallet;

                        if (state is ExpenseLoaded) {
                          if (tx.categoryId != null) {
                            category = state.getCategory(tx.categoryId!);
                          }
                          wallet = state.getWallet(tx.walletId);
                          final targetWalletId = tx.toWalletId;
                          if (targetWalletId != null) {
                            toWallet = state.getWallet(targetWalletId);
                          }
                        }

                        final isTransfer = tx is TransferTransaction;
                        final deleteLabel = isTransfer ? "Revert" : "Delete";

                        return Dismissible(
                          key: Key('tx_${tx.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.only(right: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  deleteLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) => _confirmDeleteDialog(
                            context,
                            tx,
                            wallet,
                            toWallet,
                          ),
                          onDismissed: (direction) =>
                              _deleteTransaction(context, tx),
                          child: TransactionCard(
                            transaction: tx,
                            category: category,
                            wallet: wallet,
                            onTap: () {
                              TransactionDetailsSheet.show(
                                context,
                                transaction: tx,
                                category: category,
                                wallet: wallet,
                                onDelete: () async {
                                  final confirmed = await _confirmDeleteDialog(
                                    context,
                                    tx,
                                    wallet,
                                    toWallet,
                                  );
                                  if (confirmed && context.mounted) {
                                    _deleteTransaction(context, tx);
                                  }
                                },
                                onEdit: () => _editTransaction(context, tx),
                              );
                            },
                          ),
                        );
                      }, childCount: todayTransactions.length),
                    ),
                  ),

                // Bottom Spacing for Navigation Bar & FAB
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }
}
