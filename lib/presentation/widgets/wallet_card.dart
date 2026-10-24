import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';

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

    final cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Header: Avatar + (Name & Opening/Negative badge) + Delete Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Emoji Avatar in a polished rounded container
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.surfaceBorder.withValues(alpha: 0.8),
                ),
              ),
              child: Text(wallet.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            // Wallet Name and Status Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Delete button
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.expense,
                  size: 20,
                ),
                tooltip: "Delete Wallet",
                onPressed: onRemove,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 2. Available Balance
        Text(
          CurrencyFormatter.formatRs(balance),
          style: TextStyle(
            color: isNegative ? AppColors.expense : AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 14),

        // 3. User-Friendly Quick Action Buttons (Add Funds & Edit)
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onAddFunds,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Add Funds",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              "Edit",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 4. Financial Cash Flow Breakdown (Opening | Added | Spent)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10121A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.surfaceBorder.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: "Opening",
                  amount: CurrencyFormatter.formatRs(openingBal),
                  amountColor: AppColors.textSecondary,
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.textMuted,
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: AppColors.surfaceBorder.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _MetricTile(
                  label: "Added",
                  amount: CurrencyFormatter.formatRs(totalFunds),
                  amountColor: AppColors.primary,
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: AppColors.surfaceBorder.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _MetricTile(
                  label: "Spent",
                  amount: CurrencyFormatter.formatRs(totalSpent),
                  amountColor: AppColors.expense,
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E212E), Color(0xFF151722)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isNegative
              ? AppColors.expense.withValues(alpha: 0.5)
              : AppColors.surfaceBorder.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: cardBody,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;
  final IconData icon;
  final Color iconColor;

  const _MetricTile({
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11.5, color: iconColor),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: amountColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
