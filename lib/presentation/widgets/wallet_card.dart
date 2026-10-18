import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/emoji_avatar.dart';

class WalletCard extends StatelessWidget {
  final Wallet wallet;
  final double balance;
  final double totalFunds;
  final double totalSpent;
  final VoidCallback onEdit;
  final VoidCallback onAddFunds;
  final VoidCallback onRemove;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.balance,
    required this.totalFunds,
    required this.totalSpent,
    required this.onEdit,
    required this.onAddFunds,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = balance < 0;
    final openingBal = wallet.openingBalance;

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
          // Header: Avatar + Name (Expanded) | 3-dot Popup Menu at top-right end
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EmojiAvatar(
                emoji: wallet.emoji,
                size: 42,
                fontSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                          color: AppColors.expense.withValues(alpha: 0.15),
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
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 36,
                height: 36,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  tooltip: "Wallet Actions",
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  onSelected: (val) {
                    switch (val) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'add_funds':
                        onAddFunds();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 10),
                          Text("Edit", style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_funds',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 10),
                          Text("Add Funds", style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                          SizedBox(width: 10),
                          Text("Remove", style: TextStyle(color: AppColors.expense, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Prominent Balance Display
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatRs(balance),
              style: TextStyle(
                color: isNegative ? AppColors.expense : AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Responsive 3-column stats layout: each cell has label above value with FittedBox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: "Opening",
                    value: CurrencyFormatter.formatRs(openingBal),
                    valueColor: AppColors.textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.surfaceBorder.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _StatCell(
                    label: "Added",
                    value: CurrencyFormatter.formatRs(totalFunds),
                    valueColor: AppColors.primary,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.surfaceBorder.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _StatCell(
                    label: "Spent",
                    value: CurrencyFormatter.formatRs(totalSpent),
                    valueColor: AppColors.expense,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData? icon;

  const _StatCell({
    required this.label,
    required this.value,
    required this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 11, color: valueColor),
                  const SizedBox(width: 2),
                ],
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
