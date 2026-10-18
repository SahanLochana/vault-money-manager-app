import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_state.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/theme/category_ui_helper.dart';

class CategoryPieChartCard extends StatefulWidget {
  final List<CategorySpending> categories;
  final double totalSpend;

  const CategoryPieChartCard({
    super.key,
    required this.categories,
    required this.totalSpend,
  });

  @override
  State<CategoryPieChartCard> createState() => _CategoryPieChartCardState();
}

class _CategoryPieChartCardState extends State<CategoryPieChartCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final nonZeroCategories =
        widget.categories.where((c) => c.amount > 0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: nonZeroCategories.isEmpty
          ? const SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  "No expenses recorded",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : SizedBox(
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 100,
                      sections: nonZeroCategories.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final isTouched = i == _touchedIndex;
                        final radius = isTouched ? 38.0 : 30.0;
                        final color = CategoryUIHelper.getColor(
                          item.category,
                        );

                        return PieChartSectionData(
                          color: color,
                          value: item.amount,
                          title: '${item.percentage.round()}%',
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 13 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Total Spent",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Rs ${widget.totalSpend.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
