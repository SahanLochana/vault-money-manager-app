import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/ledger_transaction.dart';
import 'package:money_management_app/domain/models/wallet.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_state.dart';
import 'package:money_management_app/presentation/screens/main_shell.dart';
import 'package:money_management_app/presentation/screens/manage_categories_page.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/theme/category_ui_helper.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TransactionMode { expense, income, transfer }

class AddTransactionPage extends StatefulWidget {
  final LedgerTransaction? transactionToEdit;
  final TransactionMode initialMode;
  final int? initialCategoryId;
  final double? initialAmount;

  const AddTransactionPage({
    super.key,
    LedgerTransaction? transactionToEdit,
    LedgerTransaction? expenseToEdit,
    this.initialMode = TransactionMode.expense,
    this.initialCategoryId,
    this.initialAmount,
  }) : transactionToEdit = transactionToEdit ?? expenseToEdit;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  late TransactionMode _mode;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  Category? _selectedCategory;
  Wallet? _selectedWallet;

  // For Transfer Mode
  Wallet? _fromWallet;
  Wallet? _toWallet;

  bool get isEditMode => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final tx = widget.transactionToEdit;

    if (tx != null) {
      if (tx.isExpense) {
        _mode = TransactionMode.expense;
      } else if (tx.isIncome) {
        _mode = TransactionMode.income;
      } else if (tx.isTransfer) {
        _mode = TransactionMode.transfer;
      }
      _amountController.text = tx.amount.toStringAsFixed(0);
      if (tx.note != null) _noteController.text = tx.note!;
      try {
        _selectedDate = DateTime.parse(tx.occurredDate);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
      try {
        final parts = tx.occurredTime.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {
        _selectedTime = TimeOfDay.now();
      }
    } else {
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(0);
      }
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _loadLastUsedWallet();
    }
    final expenseBloc = context.read<ExpenseBloc>();
    if (expenseBloc.state is! ExpenseLoaded) {
      expenseBloc.add(const LoadExpenses());
    }
  }

  Future<void> _loadLastUsedWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final lastWalletId = prefs.getInt('last_used_wallet_id');
    if (lastWalletId != null && mounted) {
      final state = context.read<ExpenseBloc>().state;
      if (state is ExpenseLoaded) {
        final w = state.getWallet(lastWalletId);
        if (w != null) {
          setState(() => _selectedWallet = w);
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (_mode) {
      case TransactionMode.expense:
        return AppColors.expense;
      case TransactionMode.income:
        return AppColors.income;
      case TransactionMode.transfer:
        return AppColors.secondary;
    }
  }

  String get _pageTitle {
    if (isEditMode) return 'Edit Transaction';
    switch (_mode) {
      case TransactionMode.expense:
        return 'Add Expense';
      case TransactionMode.income:
        return 'Add Income';
      case TransactionMode.transfer:
        return 'Transfer Funds';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _accentColor,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _accentColor,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _onSave(List<Category> categories, List<Wallet> wallets) async {
    final amountText = _amountController.text.trim();
    final parsedAmount = double.tryParse(amountText);

    if (parsedAmount == null || parsedAmount <= 0) {
      AppSnackBar.show(context, message: "Amount must be greater than 0", isError: true);
      return;
    }

    final wallet = _selectedWallet ?? wallets.firstOrNull;
    if (wallet == null && _mode != TransactionMode.transfer) {
      AppSnackBar.show(context, message: "Please select a wallet", isError: true);
      return;
    }

    if (wallet != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_used_wallet_id', wallet.id);
    }

    if (!mounted) return;

    final amountCents = (parsedAmount * 100).toInt();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final note = _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null;

    if (_mode == TransactionMode.income) {
      final categoryId = _selectedCategory?.id;
      final incomeTx = IncomeTransaction(
        id: isEditMode ? widget.transactionToEdit?.id : null,
        walletId: wallet!.id,
        categoryId: categoryId,
        amountCents: amountCents,
        occurredDate: dateStr,
        occurredTime: timeStr,
        note: note,
        createdAt: isEditMode
            ? (widget.transactionToEdit?.createdAt ?? DateTime.now().toIso8601String())
            : DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (isEditMode) {
        context.read<ExpenseBloc>().add(UpdateExpenseEvent(incomeTx));
      } else {
        context.read<ExpenseBloc>().add(AddExpenseEvent(incomeTx));
      }

      if (mounted) {
        final catName = _selectedCategory?.name ?? "Uncategorized";
        AppSnackBar.show(
          context,
          message: "Added Rs ${parsedAmount.toStringAsFixed(0)} ($catName) to ${wallet.name}",
        );
        _handleBackNavigation();
      }
      return;
    }

    if (_mode == TransactionMode.transfer) {
      final from = _fromWallet ??
          wallets.where((w) => w.name == 'In Bank').firstOrNull ??
          (wallets.length > 1 ? wallets[1] : wallets.firstOrNull);
      final to = _toWallet ??
          wallets.where((w) => w.name == 'In Hand').firstOrNull ??
          wallets.firstOrNull;

      if (from == null || to == null) {
        AppSnackBar.show(context, message: "Please select source and destination wallets", isError: true);
        return;
      }

      if (from.id == to.id) {
        AppSnackBar.show(context, message: "Cannot transfer to the same wallet", isError: true);
        return;
      }

      final transferTx = TransferTransaction(
        id: isEditMode ? widget.transactionToEdit?.id : null,
        walletId: from.id,
        toWalletId: to.id,
        amountCents: amountCents,
        occurredDate: dateStr,
        occurredTime: timeStr,
        note: note,
        createdAt: isEditMode
            ? (widget.transactionToEdit?.createdAt ?? DateTime.now().toIso8601String())
            : DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (isEditMode) {
        context.read<ExpenseBloc>().add(UpdateExpenseEvent(transferTx));
      } else {
        context.read<ExpenseBloc>().add(AddExpenseEvent(transferTx));
      }

      if (mounted) {
        AppSnackBar.show(
          context,
          message: "Transferred Rs ${parsedAmount.toStringAsFixed(0)} from ${from.name} to ${to.name}",
        );
        _handleBackNavigation();
      }
      return;
    }

    // Expense Mode
    final categoryId = _selectedCategory?.id;
    final expenseTx = ExpenseTransaction(
      id: isEditMode ? widget.transactionToEdit?.id : null,
      categoryId: categoryId,
      amountCents: amountCents,
      walletId: wallet!.id,
      occurredDate: dateStr,
      occurredTime: timeStr,
      note: note,
      createdAt: isEditMode
          ? (widget.transactionToEdit?.createdAt ?? DateTime.now().toIso8601String())
          : DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (isEditMode) {
      context.read<ExpenseBloc>().add(UpdateExpenseEvent(expenseTx));
    } else {
      context.read<ExpenseBloc>().add(AddExpenseEvent(expenseTx));
    }

    if (mounted) {
      AppSnackBar.show(
        context,
        message: isEditMode ? "Expense updated successfully" : "Expense added successfully",
      );
      _handleBackNavigation();
    }
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  Future<void> _openManageCategories(CategoryTab tab) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageCategoriesPage(initialTab: tab),
      ),
    );
    if (mounted) {
      context.read<ExpenseBloc>().add(const LoadExpenses());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, state) {
        List<Category> allCategories = [];
        List<Wallet> wallets = [];

        if (state is ExpenseLoaded) {
          allCategories = state.categories;
          wallets = state.activeWallets;

          final expectedKind = _mode == TransactionMode.income ? CategoryKind.income : CategoryKind.expense;
          final modeCategories = allCategories.where((c) => c.kind == expectedKind).toList();

          final currentTx = widget.transactionToEdit;
          if (isEditMode && _selectedCategory == null) {
            if (currentTx?.categoryId != null) {
              _selectedCategory = state.getCategory(currentTx!.categoryId!);
            }
          } else if (_selectedCategory == null && widget.initialCategoryId != null) {
            _selectedCategory = state.getCategory(widget.initialCategoryId!);
            if (_selectedCategory != null &&
                _selectedCategory!.defaultAmountCents > 0 &&
                _amountController.text.isEmpty) {
              _amountController.text = _selectedCategory!.defaultAmount.toStringAsFixed(0);
            }
          }

          // Auto-select first category if none selected, or when switching modes
          if (_selectedCategory == null && modeCategories.isNotEmpty && !isEditMode) {
            _selectedCategory = modeCategories.first;
            if (_selectedCategory!.defaultAmountCents > 0 && _amountController.text.isEmpty) {
              _amountController.text = _selectedCategory!.defaultAmount.toStringAsFixed(0);
            }
          } else if (_selectedCategory != null && _selectedCategory!.kind != expectedKind) {
            _selectedCategory = modeCategories.firstOrNull;
            if (_selectedCategory != null &&
                _selectedCategory!.defaultAmountCents > 0 &&
                _amountController.text.isEmpty) {
              _amountController.text = _selectedCategory!.defaultAmount.toStringAsFixed(0);
            }
          }

          if (isEditMode && _selectedWallet == null && currentTx != null) {
            _selectedWallet = state.getWallet(currentTx.walletId);
          }
          _selectedWallet ??= wallets.firstOrNull;
          _fromWallet ??= wallets.where((w) => w.name == 'In Bank').firstOrNull ??
              (wallets.length > 1 ? wallets[1] : wallets.firstOrNull);
          _toWallet ??= wallets.where((w) => w.name == 'In Hand').firstOrNull ??
              wallets.firstOrNull;
        }

        final filteredCategories = _mode == TransactionMode.income
            ? allCategories.where((c) => c.kind == CategoryKind.income).toList()
            : allCategories.where((c) => c.kind == CategoryKind.expense).toList();

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBackAppBar(
              title: _pageTitle,
              leadingIcon: Icons.close_rounded,
              onLeadingTap: _handleBackNavigation,
              titleFontWeight: FontWeight.w700,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Mode Selector (hide during Edit)
                    if (!isEditMode) ...[
                      _buildModeSelector(),
                      const SizedBox(height: 24),
                    ],

                    // Large Amount Input
                    _buildAmountInput(),
                    const SizedBox(height: 24),

                    // Mode Specific Content
                    if (_mode == TransactionMode.transfer) ...[
                      _buildTransferWalletsSection(wallets),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Categories Section with Right Kind + Uncategorized Option
                      _buildCategorySection(
                        filteredCategories,
                        tab: _mode == TransactionMode.income
                            ? CategoryTab.income
                            : CategoryTab.expense,
                      ),
                      const SizedBox(height: 20),

                      // Wallet Selection
                      _buildWalletSection(
                        wallets,
                        title: _mode == TransactionMode.income
                            ? "Deposit Into Wallet"
                            : "Payment Wallet",
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Date & Time Row
                    _buildDateTimeSection(),
                    const SizedBox(height: 20),

                    // Optional Note Input
                    _buildNoteInput(),
                    const SizedBox(height: 32),

                    // Save Button
                    _buildSaveButton(allCategories, wallets),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          _buildModeTab("Expense", TransactionMode.expense, AppColors.expense),
          _buildModeTab("Income", TransactionMode.income, AppColors.income),
          _buildModeTab("Transfer", TransactionMode.transfer, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, TransactionMode mode, Color color) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            _selectedCategory = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.4), width: 1.2)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          const Text(
            "Enter Amount",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Rs ",
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IntrinsicWidth(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                  decoration: const InputDecoration(
                    hintText: "0",
                    hintStyle: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(List<Category> categories, {required CategoryTab tab}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tab == CategoryTab.income ? "Income Source" : "Category",
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () => _openManageCategories(tab),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: _accentColor),
                  const SizedBox(width: 4),
                  Text(
                    "Manage",
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCategoryGrid(categories),
      ],
    );
  }

  Widget _buildCategoryGrid(List<Category> categories) {
    if (categories.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("❓", style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    Text(
                      "Uncategorized",
                      style: TextStyle(
                        color: _accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // When more than 5 categories: exactly 2 rows of 3 chips (5 direct + 1 dropdown for the rest)
    if (categories.length > 5) {
      final row1 = categories.take(3).map(_buildCategoryChip).toList();
      final row2 = [
        _buildCategoryChip(categories[3]),
        _buildCategoryChip(categories[4]),
        _buildMoreCategoriesDropdown(categories.skip(5).toList()),
      ];
      return Column(
        children: [
          _buildCategoryRow(row1),
          const SizedBox(height: 8),
          _buildCategoryRow(row2),
        ],
      );
    }

    // 5 categories: 2 rows (3 in Row 1, 2 in Row 2) with no dropdown chip
    if (categories.length == 5) {
      final row1 = categories.take(3).map(_buildCategoryChip).toList();
      final row2 = categories.skip(3).map(_buildCategoryChip).toList();
      return Column(
        children: [
          _buildCategoryRow(row1),
          const SizedBox(height: 8),
          _buildCategoryRow(row2),
        ],
      );
    }

    // 4 categories: 2 rows of 2 chips
    if (categories.length == 4) {
      final row1 = categories.take(2).map(_buildCategoryChip).toList();
      final row2 = categories.skip(2).map(_buildCategoryChip).toList();
      return Column(
        children: [
          _buildCategoryRow(row1),
          const SizedBox(height: 8),
          _buildCategoryRow(row2),
        ],
      );
    }

    // 1 to 3 categories: single row
    return _buildCategoryRow(categories.map(_buildCategoryChip).toList());
  }

  Widget _buildCategoryRow(List<Widget> children) {
    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _buildCategoryChip(Category cat) {
    final isSelected = _selectedCategory?.id == cat.id;
    final catColor = CategoryUIHelper.getColor(cat);
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = cat;
          if (cat.defaultAmountCents > 0) {
            _amountController.text = cat.defaultAmount.toStringAsFixed(0);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? catColor.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? catColor.withValues(alpha: 0.6) : AppColors.surfaceBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cat.emoji,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? catColor : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreCategoriesDropdown(List<Category> remainingCategories) {
    final isSelectedFromRemaining = remainingCategories.any((c) => c.id == _selectedCategory?.id);
    final activeCat = isSelectedFromRemaining ? _selectedCategory : null;
    final activeColor = activeCat != null
        ? CategoryUIHelper.getColor(activeCat)
        : AppColors.textSecondary;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.surfaceBorder.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
        ),
      ),
      child: PopupMenuButton<Category>(
        tooltip: "More Categories",
        offset: const Offset(0, 48),
        elevation: 8,
        onSelected: (Category cat) {
          setState(() {
            _selectedCategory = cat;
            if (cat.defaultAmountCents > 0) {
              _amountController.text = cat.defaultAmount.toStringAsFixed(0);
            }
          });
        },
        itemBuilder: (context) => remainingCategories.map((cat) {
          final isSelected = _selectedCategory?.id == cat.id;
          final catColor = CategoryUIHelper.getColor(cat);
          return PopupMenuItem<Category>(
            value: cat,
            child: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: isSelected ? catColor : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_rounded, size: 16, color: catColor),
              ],
            ),
          );
        }).toList(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: isSelectedFromRemaining
                ? activeColor.withValues(alpha: 0.18)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelectedFromRemaining
                  ? activeColor.withValues(alpha: 0.6)
                  : AppColors.surfaceBorder,
              width: isSelectedFromRemaining ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (activeCat != null) ...[
                Text(activeCat.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    activeCat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.more_horiz_rounded, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "More (${remainingCategories.length})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: isSelectedFromRemaining ? activeColor : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSection(List<Wallet> wallets, {String title = "Payment Wallet"}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: wallets.map((wallet) {
            final isSelected = _selectedWallet?.id == wallet.id;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedWallet = wallet);
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: wallet == wallets.first ? 8 : 0,
                    left: wallet == wallets.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.surfaceBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        wallet.emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        wallet.name,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTransferWalletsSection(List<Wallet> wallets) {
    final fromName = _fromWallet?.name ?? 'In Bank';
    final toName = _toWallet?.name ?? 'In Hand';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Transfer Between Wallets",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "From",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fromName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    final temp = _fromWallet;
                    _fromWallet = _toWallet;
                    _toWallet = temp;
                  });
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "To",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      toName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    final formattedDate = DateFormat('dd MMM yyyy').format(_selectedDate);
    final formattedTime = _selectedTime.format(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Date",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Time",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteInput() {
    return LabeledField(
      label: "Note (Optional)",
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      child: AppTextField(
        controller: _noteController,
        maxLines: 2,
        hintText: "Add any extra context or note...",
        fillColor: AppColors.surface,
        borderRadius: 16,
        accentColor: _accentColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSaveButton(List<Category> categories, List<Wallet> wallets) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _onSave(categories, wallets),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: const Color(0xFF0F0F14),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Text(
          isEditMode
              ? "Update Transaction"
              : _mode == TransactionMode.transfer
                  ? "Complete Transfer"
                  : (_mode == TransactionMode.income ? "Save Income" : "Save Expense"),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
