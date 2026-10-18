import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/models/wallet_fund.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';

class AddFundsDialog extends StatefulWidget {
  final List<Wallet> wallets;
  final Wallet? preselectedWallet;

  const AddFundsDialog({
    super.key,
    required this.wallets,
    this.preselectedWallet,
  });

  static Future<WalletFund?> show(
    BuildContext context, {
    required List<Wallet> wallets,
    Wallet? preselectedWallet,
  }) {
    return showDialog<WalletFund>(
      context: context,
      builder: (context) => AddFundsDialog(
        wallets: wallets,
        preselectedWallet: preselectedWallet,
      ),
    );
  }

  @override
  State<AddFundsDialog> createState() => _AddFundsDialogState();
}

class _AddFundsDialogState extends State<AddFundsDialog> {
  late int _selectedWalletId;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  String? _amountError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedWalletId = widget.preselectedWallet?.id ??
        (widget.wallets.isNotEmpty ? widget.wallets.first.id : 0);
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    if (_isSubmitting) return;

    final rawAmount = _amountController.text.trim();
    final cents = CurrencyFormatter.tryParseToCents(rawAmount);

    if (cents == null || cents <= 0) {
      setState(() {
        _amountError = "Enter an amount greater than Rs 0.00.";
      });
      return;
    }

    setState(() {
      _amountError = null;
      _isSubmitting = true;
    });

    final fund = WalletFund(
      walletId: _selectedWalletId,
      amountCents: cents,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );

    Navigator.of(context).pop(fund);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AppDialogShell(
          title: "Add Funds to Wallet",
          confirmLabel: "Add Funds",
          confirmColor: AppColors.primary,
          onConfirm: _isSubmitting ? null : _validateAndSubmit,
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
                        value: _selectedWalletId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: widget.wallets.map((w) {
                          return DropdownMenuItem<int>(
                            value: w.id,
                            child: Row(
                              children: [
                                Text(
                                  w.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedWalletId = val);
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
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    hintText: "0.00",
                    prefixText: "Rs ",
                    errorText: _amountError,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    textStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Note (Optional)",
                  child: AppTextField(
                    controller: _noteController,
                    hintText: "e.g. Salary, ATM withdrawal, Deposit",
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _validateAndSubmit(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
