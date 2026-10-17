import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/presentation/blocs/category/category_bloc.dart';
import 'package:money_management_app/presentation/blocs/category/category_event.dart';
import 'package:money_management_app/presentation/blocs/category/category_state.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_bloc.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_event.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_bloc.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_event.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/category_list_view.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';
import 'package:money_management_app/presentation/widgets/emoji_picker_grid.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';
import 'package:money_management_app/presentation/widgets/pill_action_button.dart';

enum CategoryTab { expense, income }

class ManageCategoriesPage extends StatefulWidget {
  final CategoryTab initialTab;

  const ManageCategoriesPage({
    super.key,
    this.initialTab = CategoryTab.expense,
  });

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  late CategoryTab _currentTab;

  Color get _tabAccent =>
      _currentTab == CategoryTab.expense ? AppColors.primary : AppColors.income;

  static const List<String> _expenseEmojis = [
    '🍳', '🍔', '🌙', '☕', '🍕', '🚗', '🛍️', '💊',
    '🎮', '📚', '🏋️', '✈️', '🎬', '💡', '🏠', '🤝',
    '🍿', '🏷️', '🛒', '⛽', '🚌', '🏥', '💈', '👗',
  ];

  static const List<String> _incomeEmojis = [
    '💰', '💵', '💳', '🏦', '💼', '📈', '🎯', '💹',
    '🏠', '🚀', '💎', '🎁', '⭐', '🌟', '💡', '🤝',
    '📊', '🏆', '🪙', '💸', '🧧', '🏷️',
  ];

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    context.read<CategoryBloc>().add(const LoadCategoriesEvent());
  }

  Future<void> _addOrEditCategoryDialog({Category? categoryToEdit}) async {
    final isEditing = categoryToEdit != null;
    final isIncome = isEditing
        ? categoryToEdit.isIncome
        : _currentTab == CategoryTab.income;

    final nameCtrl = TextEditingController(text: categoryToEdit?.name ?? '');
    final defaultAmountCtrl = TextEditingController(
      text: (categoryToEdit != null && categoryToEdit.defaultAmountCents > 0)
          ? categoryToEdit.defaultAmount.toStringAsFixed(2)
          : '',
    );
    String selectedEmoji = categoryToEdit?.emoji ?? (isIncome ? '💰' : '🏷️');
    final emojis = isIncome ? _incomeEmojis : _expenseEmojis;
    final accent = isIncome ? AppColors.income : AppColors.primary;

    final result = await showDialog<Category>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          title: isEditing
              ? "Edit ${isIncome ? 'Income' : 'Expense'} Category"
              : "Add ${isIncome ? 'Income' : 'Expense'} Category",
          confirmColor: accent,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: "Choose Emoji",
                  child: EmojiPickerGrid(
                    emojis: emojis,
                    selectedEmoji: selectedEmoji,
                    onSelected: (e) => setDialogState(() => selectedEmoji = e),
                    accentColor: accent,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Category Name",
                  child: AppTextField(
                    controller: nameCtrl,
                    autofocus: !isEditing,
                    hintText: isIncome
                        ? "e.g. Salary, Freelance, Dividends"
                        : "e.g. Gym, Coffee, Groceries",
                    accentColor: accent,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Default Amount (Optional)",
                  child: AppTextField(
                    controller: defaultAmountCtrl,
                    hintText: "0.00",
                    prefixText: "Rs ",
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    accentColor: accent,
                  ),
                ),
              ],
            ),
          ),
          onConfirm: () {
            final name = nameCtrl.text.trim();
            if (name.isNotEmpty) {
              final amtVal = double.tryParse(defaultAmountCtrl.text.trim()) ?? 0.0;
              final defaultCents = (amtVal * 100).round();

              if (isEditing) {
                Navigator.pop(
                  context,
                  categoryToEdit.copyWith(
                    name: name,
                    emoji: selectedEmoji,
                    defaultAmountCents: defaultCents,
                  ),
                );
              } else {
                Navigator.pop(
                  context,
                  Category(
                    kind: isIncome ? CategoryKind.income : CategoryKind.expense,
                    name: name,
                    emoji: selectedEmoji,
                    defaultAmountCents: defaultCents,
                  ),
                );
              }
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      if (isEditing) {
        context.read<CategoryBloc>().add(UpdateCategoryEvent(result));
        context.read<ExpenseBloc>().add(const LoadExpenses());
        context.read<ReminderBloc>().add(const LoadRemindersEvent());
        AppSnackBar.show(
          context,
          message: "Category '${result.name}' updated",
        );
      } else {
        context.read<CategoryBloc>().add(AddCategoryEvent(result));
        AppSnackBar.show(
          context,
          message: "${isIncome ? 'Income' : 'Expense'} Category '${result.name}' added",
        );
      }
    }
  }

  Future<void> _deleteCategoryDialog(Category cat) async {
    if (cat.id == null) return;
    final catId = cat.id!;

    final impact = await context.read<CategoryBloc>().getDeleteImpact(catId);
    if (!mounted) return;

    final infoMessage =
        "${impact.transactionCount} transaction(s) will keep this category name.\n${impact.reminderCount} linked reminder(s) will be removed.";

    final confirmed = await ConfirmActionDialog.show(
      context,
      title: "Delete '${cat.name}'?",
      titleIcon: Icons.warning_amber_rounded,
      titleIconColor: AppColors.expense,
      message: "Are you sure you want to delete ${cat.emoji} ${cat.name}?",
      confirmLabel: "Delete Category",
      confirmColor: AppColors.expense,
      infoBox: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.expense,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                infoMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed && mounted) {
      context.read<CategoryBloc>().add(DeleteCategoryEvent(catId));
      context.read<ExpenseBloc>().add(const LoadExpenses());
      context.read<ReminderBloc>().add(const LoadRemindersEvent());
      final now = DateTime.now();
      context.read<StatsBloc>().add(
        LoadMonthlyStatsEvent(year: now.year, month: now.month),
      );

      AppSnackBar.show(
        context,
        message: "Deleted '${cat.name}'",
        actionLabel: "Undo",
        onAction: () {
          context.read<CategoryBloc>().add(RestoreCategoryEvent(catId));
          context.read<ExpenseBloc>().add(const LoadExpenses());
          context.read<ReminderBloc>().add(const LoadRemindersEvent());
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBackAppBar(
        title: "Manage Categories",
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PillActionButton(
              label: _currentTab == CategoryTab.expense ? "Add Expense" : "Add Income",
              icon: Icons.add_rounded,
              color: _tabAccent,
              onPressed: () => _addOrEditCategoryDialog(),
            ),
          ),
        ],
      ),
      body: BlocConsumer<CategoryBloc, CategoryState>(
        listener: (context, state) {
          if (state is CategoryError) {
            AppSnackBar.show(context, message: state.message, isError: true);
          }
        },
        builder: (context, state) {
          final expenseCategories = (state is CategoryLoaded)
              ? state.expenseCategories
              : <Category>[];
          final incomeCategories = (state is CategoryLoaded)
              ? state.incomeCategories
              : <Category>[];

          return Column(
            children: [
              // Segmented Tab Selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: "Expense",
                        count: expenseCategories.length,
                        tab: CategoryTab.expense,
                        activeColor: AppColors.expense,
                      ),
                      _buildTabButton(
                        label: "Income",
                        count: incomeCategories.length,
                        tab: CategoryTab.income,
                        activeColor: AppColors.income,
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Body
              Expanded(
                child: state is CategoryLoading
                    ? AppLoadingIndicator(color: _tabAccent)
                    : _buildCategoriesList(
                        _currentTab == CategoryTab.expense
                            ? expenseCategories
                            : incomeCategories,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int count,
    required CategoryTab tab,
    required Color activeColor,
  }) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeColor : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.25)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? activeColor : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<Category> categories) {
    if (categories.isEmpty) {
      return Center(
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
              child: Icon(
                Icons.category_outlined,
                color: AppColors.textMuted,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "No ${_currentTab == CategoryTab.expense ? 'Expense' : 'Income'} Categories",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Tap 'Add ${_currentTab == CategoryTab.expense ? 'Expense' : 'Income'}' to create one",
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return CategoryListView<Category>(
      categories: categories,
      emoji: (cat) => cat.emoji,
      name: (cat) => cat.name,
      subtitle: (cat) => cat.defaultAmountCents > 0
          ? "Default: Rs ${cat.defaultAmount.toStringAsFixed(0)}"
          : null,
      onEdit: (cat) => _addOrEditCategoryDialog(categoryToEdit: cat),
      onDelete: _deleteCategoryDialog,
      deleteTooltip: "Delete Category",
    );
  }
}
