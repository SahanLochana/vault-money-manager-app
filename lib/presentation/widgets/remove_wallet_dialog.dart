import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';

class RemoveWalletDialog {
  /// Prompts the user to select another wallet to receive the remaining balance before removing.
  static Future<int?> showMoveBalanceDialog(
    BuildContext context, {
    required Wallet walletToRemove,
    required List<Wallet> otherWallets,
  }) async {
    if (otherWallets.isEmpty) return null;

    int selectedTargetId = otherWallets.first.id;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final targetWallet = otherWallets.firstWhere((w) => w.id == selectedTargetId);
          final formattedBalance = CurrencyFormatter.formatRs(walletToRemove.balance);

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.surfaceBorder),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Move Balance & Remove",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "'${walletToRemove.name}' has a balance of $formattedBalance. Move this balance to another wallet before removing:",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Transfer balance to:",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedTargetId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: otherWallets.map((w) {
                          return DropdownMenuItem<int>(
                            value: w.id,
                            child: Row(
                              children: [
                                Text(w.emoji, style: const TextStyle(fontSize: 16)),
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
                            setState(() => selectedTargetId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "A transfer of $formattedBalance to '${targetWallet.name}' will be recorded, and '${walletToRemove.name}' will be archived. History is preserved.",
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(selectedTargetId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Move & Remove",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Prompts confirmation to archive a wallet with zero balance that has historical transactions.
  static Future<bool> confirmArchive(
    BuildContext context, {
    required Wallet wallet,
  }) {
    return ConfirmActionDialog.show(
      context,
      title: "Archive Wallet",
      message:
          "'${wallet.name}' has past transactions recorded. It will be archived and hidden from pickers and totals, while all your past history remains preserved.",
      confirmLabel: "Archive",
      confirmColor: AppColors.expense,
      titleIcon: Icons.archive_outlined,
      titleIconColor: AppColors.expense,
    );
  }

  /// Prompts confirmation to permanently delete a wallet that has zero balance and no transaction history.
  static Future<bool> confirmPermanentDelete(
    BuildContext context, {
    required Wallet wallet,
  }) {
    return ConfirmActionDialog.show(
      context,
      title: "Delete Wallet",
      message:
          "'${wallet.name}' has no transaction history. It will be permanently removed from Vault.",
      confirmLabel: "Delete Permanently",
      confirmColor: AppColors.expense,
      titleIcon: Icons.delete_forever_rounded,
      titleIconColor: AppColors.expense,
    );
  }
}
