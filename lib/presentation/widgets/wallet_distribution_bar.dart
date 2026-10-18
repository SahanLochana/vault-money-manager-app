import 'package:flutter/material.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';

class WalletDistributionBar extends StatelessWidget {
  final List<Wallet> wallets;
  final Map<int, double> balances;

  const WalletDistributionBar({
    super.key,
    required this.wallets,
    required this.balances,
  });

  @override
  Widget build(BuildContext context) {
    final positiveWallets = wallets.where((w) {
      final b = balances[w.id] ?? w.balance;
      return b > 0;
    }).toList();

    final totalPositive = positiveWallets.fold<double>(
      0.0,
      (sum, w) => sum + (balances[w.id] ?? w.balance),
    );

    if (totalPositive <= 0 || positiveWallets.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6,
          width: double.infinity,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: positiveWallets.map((wallet) {
            final balance = balances[wallet.id] ?? wallet.balance;
            final flex = ((balance / totalPositive) * 1000).round();
            final color = AppColors.categoryPalette[
                wallet.id % AppColors.categoryPalette.length];

            return Expanded(
              flex: flex > 0 ? flex : 1,
              child: Container(
                color: color,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
