import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_state.dart';
import 'package:money_management_app/presentation/screens/add_transaction_page.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';
import 'package:money_management_app/presentation/widgets/transaction_details_sheet.dart';
import 'package:money_management_app/presentation/widgets/transactioncard.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedFilter = 'All';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll - currentScroll <= 300) {
        final state = context.read<ExpenseBloc>().state;
        if (state is ExpenseLoaded && state.hasMoreHistory && !state.isLoadingMore) {
          context.read<ExpenseBloc>().add(const LoadMoreExpenses());
        }
      }
    }
  }

  void _deleteTransaction(LedgerTransaction tx) {
    if (tx.id == null) return;
    final txId = tx.id!;
    context.read<ExpenseBloc>().add(DeleteExpenseEvent(txId));

    String actionMsg;
    if (tx is TransferTransaction) {
      actionMsg = "Reverted transfer (${tx.formattedAmount})";
    } else if (tx is IncomeTransaction) {
      actionMsg = "Deleted income (${tx.formattedAmount})";
    } else {
      actionMsg = "Deleted expense (${tx.formattedAmount}) • Restored to wallet";
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

  Future<bool> _confirmDeleteDialog(LedgerTransaction tx, Wallet? wallet, Wallet? toWallet) async {
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

  void _editTransaction(LedgerTransaction tx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AddTransactionPage(transactionToEdit: tx),
      ),
    );
  }

  String _formatDateHeader(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      if (dateOnly == today) {
        return "TODAY";
      } else if (dateOnly == yesterday) {
        return "YESTERDAY";
      } else {
        return DateFormat('EEE, d MMM yyyy').format(parsed).toUpperCase();
      }
    } catch (_) {
      return rawDate.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBackAppBar(
        title: "History",
        hasLeading: false,
        titleSpacing: 20,
        titleFontSize: 24,
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

          final Map<String, List<LedgerTransaction>> grouped = {};
          bool isLoadingMore = false;

          if (state is ExpenseLoaded) {
            isLoadingMore = state.isLoadingMore;

            final selectedWallet = _selectedFilter == 'All'
                ? null
                : state.wallets.where((w) => w.name == _selectedFilter).firstOrNull;

            final filteredList = state.historyTransactions.where((tx) {
              if (selectedWallet == null) return true;
              if (tx.walletId == selectedWallet.id) return true;
              if (tx is TransferTransaction && tx.toWalletId == selectedWallet.id) return true;
              return false;
            }).toList();

            for (final tx in filteredList) {
              final date = tx.date;
              grouped.putIfAbsent(date, () => []).add(tx);
            }
          }

          final groupKeys = grouped.keys.toList();

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Wallet Horizontal Filter Chips
              if (state is ExpenseLoaded && state.wallets.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _selectedFilter == 'All',
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedFilter = 'All');
                              }
                            },
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: _selectedFilter == 'All'
                                  ? Colors.black
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _selectedFilter == 'All'
                                    ? AppColors.primary
                                    : AppColors.surfaceBorder,
                              ),
                            ),
                          ),
                          ...state.wallets.map((wallet) {
                            final isSelected = _selectedFilter == wallet.name;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ChoiceChip(
                                label: Text("${wallet.emoji} ${wallet.name}"),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedFilter = wallet.name);
                                  }
                                },
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceBorder,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

              if (groupKeys.isEmpty)
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
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: const Icon(
                              Icons.history_toggle_off_rounded,
                              color: AppColors.textMuted,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "No transaction history",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Your recorded transactions will show up here",
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final groupKey = groupKeys[index];
                        final groupItems = grouped[groupKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                _formatDateHeader(groupKey),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            ...groupItems.map(
                              (tx) {
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
                                  key: Key('history_tx_${tx.id}'),
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
                                  confirmDismiss: (direction) =>
                                      _confirmDeleteDialog(tx, wallet, toWallet),
                                  onDismissed: (direction) => _deleteTransaction(tx),
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
                                              tx, wallet, toWallet);
                                          if (confirmed && context.mounted) {
                                            _deleteTransaction(tx);
                                          }
                                        },
                                        onEdit: () => _editTransaction(tx),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                      childCount: groupKeys.length,
                    ),
                  ),
                ),

              if (isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }
}
