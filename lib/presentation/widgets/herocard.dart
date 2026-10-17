import 'package:flutter/material.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';

class TodaySpentCard extends StatelessWidget {
  final double dailySpent;
  final double dailyBudget;

  const TodaySpentCard({
    super.key,
    required this.dailySpent,
    this.dailyBudget = 500.0,
  });

  double get remainingBudget =>
      (dailyBudget - dailySpent).clamp(0.0, double.infinity);
  double get spentPercentage =>
      dailyBudget > 0 ? (dailySpent / dailyBudget).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => dailySpent > dailyBudget;

  @override
  Widget build(BuildContext context) {
    final progressColor = isOverBudget
        ? AppColors.expense
        : spentPercentage > 0.8
        ? AppColors.warning
        : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2230), Color(0xFF121620)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Label & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Spending",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: progressColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isOverBudget
                      ? "Over Budget"
                      : "${(spentPercentage * 100).toInt()}% Used",
                  style: TextStyle(
                    color: progressColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Big Spent Amount
          Text(
            "Rs ${dailySpent.toStringAsFixed(0)}",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: spentPercentage,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),

          const SizedBox(height: 14),

          // Bottom Budget Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOverBudget
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isOverBudget ? AppColors.expense : AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOverBudget
                        ? "Rs ${(dailySpent - dailyBudget).toStringAsFixed(0)} exceeded"
                        : "Rs ${remainingBudget.toStringAsFixed(0)} left",
                    style: TextStyle(
                      color: isOverBudget
                          ? AppColors.expense
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                "Daily limit: Rs ${dailyBudget.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
