import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/domain/utils/currency_formatter.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/wallet_distribution_bar.dart';

class TotalBalanceCard extends StatelessWidget {
  final double totalBalance;
  final List<Wallet> wallets;
  final Map<int, double> balances;
  final bool isBalanceHidden;
  final VoidCallback? onToggleVisibility;

  const TotalBalanceCard({
    super.key,
    required this.totalBalance,
    required this.wallets,
    required this.balances,
    this.isBalanceHidden = false,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = totalBalance < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2230), Color(0xFF121620)],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Total Available Balance",
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onToggleVisibility,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isBalanceHidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 18,
                    color: isBalanceHidden
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onToggleVisibility,
            behavior: HitTestBehavior.opaque,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: isBalanceHidden
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                      child: Text(
                        CurrencyFormatter.formatRs(totalBalance),
                        style: TextStyle(
                          color: isNegative
                              ? AppColors.expense
                              : AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    )
                  : Text(
                      CurrencyFormatter.formatRs(totalBalance),
                      style: TextStyle(
                        color: isNegative
                            ? AppColors.expense
                            : AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          WalletDistributionBar(wallets: wallets, balances: balances),
        ],
      ),
    );
  }
}
