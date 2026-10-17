import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_state.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/emoji_avatar.dart';
import 'package:money_management_app/presentation/widgets/emoji_picker_grid.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';
import 'package:money_management_app/presentation/widgets/pill_action_button.dart';

class ManageWalletsPage extends StatefulWidget {
  const ManageWalletsPage({super.key});

  @override
  State<ManageWalletsPage> createState() => _ManageWalletsPageState();
}

class _ManageWalletsPageState extends State<ManageWalletsPage> {
  static const List<String> _walletEmojis = [
    '💵', '💳', '🏦', '💰', '👛', '🪙', '💼', '🏷️',
  ];

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const LoadWalletsEvent());
  }

  Future<void> _editWalletDialog(Wallet wallet) async {
    final nameCtrl = TextEditingController(text: wallet.name);
    final openingBalanceCtrl = TextEditingController(
      text: wallet.openingBalance > 0 ? wallet.openingBalance.toStringAsFixed(2) : '0.00',
    );
    String selectedEmoji = wallet.emoji;

    final updated = await showDialog<Wallet>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          title: "Edit Wallet",
          confirmLabel: "Save",
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: "Choose Emoji",
                  child: EmojiPickerGrid(
                    emojis: _walletEmojis,
                    selectedEmoji: selectedEmoji,
                    onSelected: (e) => setDialogState(() => selectedEmoji = e),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Wallet Name",
                  child: AppTextField(
                    controller: nameCtrl,
                    hintText: "e.g. Cash, Bank Account, Savings",
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Opening Balance",
                  child: AppTextField(
                    controller: openingBalanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    hintText: "0.00",
                    prefixText: "Rs ",
                  ),
                ),
              ],
            ),
          ),
          onConfirm: () {
            final name = nameCtrl.text.trim();
            final amt = double.tryParse(openingBalanceCtrl.text.trim()) ?? 0.0;
            if (name.isNotEmpty) {
              Navigator.pop(
                context,
                wallet.copyWith(
                  name: name,
                  emoji: selectedEmoji,
                  openingBalanceCents: (amt * 100).round(),
                ),
              );
            }
          },
        ),
      ),
    );

    if (updated != null && mounted) {
      context.read<WalletBloc>().add(UpdateWalletEvent(updated));
      context.read<ExpenseBloc>().add(const LoadExpenses());
      AppSnackBar.show(context, message: "Wallet '${updated.name}' updated");
    }
  }

  Future<void> _addFundsDialog({
    Wallet? preselectedWallet,
    List<Wallet>? wallets,
  }) async {
    final availableWallets = wallets ?? [];
    if (availableWallets.isEmpty) return;

    int selectedWalletId = preselectedWallet?.id ?? availableWallets.first.id;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final result = await showDialog<WalletFund>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          title: "Add Funds to Wallet",
          confirmLabel: "Add Funds",
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: "Choose Wallet",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedWalletId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: availableWallets.map((w) {
                          return DropdownMenuItem<int>(
                            value: w.id,
                            child: Row(
                              children: [
                                Text(
                                  w.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  w.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedWalletId = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Amount",
                  child: AppTextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    hintText: "0.00",
                    prefixText: "Rs ",
                    textStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Note (Optional)",
                  child: AppTextField(
                    controller: noteCtrl,
                    hintText: "e.g. Salary, ATM withdrawal, Deposit",
                  ),
                ),
              ],
            ),
          ),
          onConfirm: () {
            final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
            if (amt > 0) {
              final fund = WalletFund(
                walletId: selectedWalletId,
                amountCents: (amt * 100).toInt(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                createdAt: DateTime.now().toIso8601String(),
              );
              Navigator.pop(context, fund);
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<WalletBloc>().add(AddWalletFundsEvent(result));
      context.read<ExpenseBloc>().add(const LoadExpenses());
      AppSnackBar.show(
        context,
        message: "Added Rs ${result.amount.toStringAsFixed(0)} to wallet",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBackAppBar(
        title: "Wallets & Balances",
        actions: [
          BlocBuilder<WalletBloc, WalletState>(
            builder: (context, state) {
              final wallets = (state is WalletLoaded) ? state.wallets : <Wallet>[];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PillActionButton(
                  label: "Add Funds",
                  icon: Icons.add_rounded,
                  color: AppColors.primary,
                  onPressed: () => _addFundsDialog(wallets: wallets),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          if (state is WalletLoading) {
            return const AppLoadingIndicator();
          }

          if (state is WalletLoaded) {
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Total Net Balance Card
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1C2230), Color(0xFF121620)],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Available Balance",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Rs ${state.grandTotalBalance.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: state.grandTotalBalance < 0
                              ? AppColors.expense
                              : AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

                // Per-Wallet Cards
                ...state.wallets.map((wallet) {
                  final balance = state.getBalance(wallet.id);
                  final totalFunds = state.getTotalFund(wallet.id);
                  final totalSpent = state.getTotalSpent(wallet.id);
                  final openingBal = wallet.openingBalance;
                  final isNegative = balance < 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isNegative
                            ? AppColors.expense.withValues(alpha: 0.4)
                            : AppColors.surfaceBorder.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                EmojiAvatar(
                                  emoji: wallet.emoji,
                                  size: 42,
                                  fontSize: 20,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wallet.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isNegative)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.expense.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "Negative balance",
                                          style: TextStyle(
                                            color: AppColors.expense,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  "Rs ${balance.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: isNegative
                                        ? AppColors.expense
                                        : AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                  tooltip: "Edit Wallet",
                                  onPressed: () => _editWalletDialog(wallet),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Opening: Rs ${openingBal.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Added: Rs ${totalFunds.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: AppColors.expense,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Spent: Rs ${totalSpent.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _addFundsDialog(
                              preselectedWallet: wallet,
                              wallets: state.wallets,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text("Add Funds"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF0F0F14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
