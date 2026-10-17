import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/screens/manage_categories_page.dart';
import 'package:money_management_app/presentation/screens/manage_reminders_page.dart';
import 'package:money_management_app/presentation/screens/manage_wallets_page.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';
import 'package:money_management_app/presentation/widgets/section_header.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _dailyBudget = 500.0;
  int _snoozeMinutes = 15;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final settingsRepo = context.read<SettingsRepository>();
    final budget = await settingsRepo.getDailyBudget();
    final snooze = await settingsRepo.getSnoozeDurationMinutes();
    if (mounted) {
      setState(() {
        _dailyBudget = budget;
        _snoozeMinutes = snooze;
      });
    }
  }

  Future<void> _updateDailyBudget(double newBudget) async {
    final settingsRepo = context.read<SettingsRepository>();
    await settingsRepo.setDailyBudget(newBudget);
    if (mounted) {
      setState(() => _dailyBudget = newBudget);
      context.read<ExpenseBloc>().add(const LoadExpenses());
    }
  }

  Future<void> _updateSnoozeMinutes(int minutes) async {
    final settingsRepo = context.read<SettingsRepository>();
    await settingsRepo.setSnoozeDurationMinutes(minutes);
    if (mounted) {
      setState(() => _snoozeMinutes = minutes);
    }
  }

  void _showEditDailyBudgetDialog() {
    final controller = TextEditingController(text: _dailyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AppDialogShell(
        title: "Edit Daily Budget",
        confirmLabel: "Save",
        content: AppTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          hintText: "Enter amount",
          prefixText: "Rs ",
        ),
        onConfirm: () {
          final val = double.tryParse(controller.text.trim());
          if (val != null && val > 0) {
            _updateDailyBudget(val);
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showEditSnoozeDialog() {
    final options = [5, 10, 15, 20, 30, 45, 60];
    showDialog(
      context: context,
      builder: (context) => AppDialogShell(
        title: "Reminder Snooze Duration",
        confirmLabel: "Done",
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((mins) {
                final isSelected = mins == _snoozeMinutes;
                return InkWell(
                  onTap: () {
                    _updateSnoozeMinutes(mins);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$mins minutes",
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        onConfirm: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final txRepo = context.read<TransactionRepository>();
      final data = await txRepo.exportAllData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final txCount = (data['transactions'] as List?)?.length ?? 0;
      final catCount = (data['categories'] as List?)?.length ?? 0;
      final walletCount = (data['wallets'] as List?)?.length ?? 0;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AppDialogShell(
          title: "Export Ledger Data",
          confirmLabel: "Copy JSON",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Exported schema v${data['schema_version']}:",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "• $txCount transactions (expenses, income, transfers)\n• $catCount categories\n• $walletCount wallets",
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonString,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          onConfirm: () {
            Clipboard.setData(ClipboardData(text: jsonString));
            Navigator.pop(context);
            AppSnackBar.show(context, message: "Exported JSON copied to clipboard");
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, message: "Export failed: $e", isError: true);
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: "Clear All Data?",
      message:
          "This will permanently delete all expenses, income, and transfers from your ledger. Categories and wallets will remain, and balances will reset to opening balances. This action cannot be undone.",
      confirmLabel: "Clear All Data",
      confirmColor: AppColors.expense,
    );

    if (confirmed && mounted) {
      final txRepo = context.read<TransactionRepository>();
      final clearedCount = await txRepo.clearAllLedgerData();

      if (mounted) {
        context.read<ExpenseBloc>().add(const LoadExpenses());
        context.read<WalletBloc>().add(const LoadWalletsEvent());
        AppSnackBar.show(
          context,
          message: "Cleared $clearedCount transactions. Balances reset to opening balances.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppBackAppBar(
        title: "Settings",
        titleFontSize: 22,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Features & Reminders Section
          const SectionHeader(title: "Alerts & Organization"),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.alarm_rounded,
            iconColor: AppColors.primary,
            title: "Daily Reminders",
            subtitle: "Manage scheduled alerts & reminder times",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageRemindersPage(),
                ),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.primary,
            title: "Wallets & Balances",
            subtitle: "View current balances, add funds, top-up history",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageWalletsPage(),
                ),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.category_rounded,
            iconColor: AppColors.secondary,
            title: "Manage Categories",
            subtitle: "Add, customize, or remove categories",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageCategoriesPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Preferences
          const SectionHeader(title: "Preferences"),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.track_changes_rounded,
            iconColor: AppColors.warning,
            title: "Daily Budget Target",
            subtitle: "Rs ${_dailyBudget.toStringAsFixed(0)} / day",
            onTap: _showEditDailyBudgetDialog,
          ),
          _buildSettingTile(
            icon: Icons.snooze_rounded,
            iconColor: AppColors.primary,
            title: "Reminder Snooze Duration",
            subtitle: "$_snoozeMinutes minutes",
            onTap: _showEditSnoozeDialog,
          ),

          const SizedBox(height: 20),

          // Data & Storage
          const SectionHeader(title: "Data Management"),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.file_download_outlined,
            iconColor: AppColors.primary,
            title: "Export All Data (JSON)",
            subtitle: "Backup all ledger transactions, categories & wallets",
            onTap: _exportData,
          ),
          _buildSettingTile(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.expense,
            title: "Clear All Data",
            subtitle: "Reset all ledger transactions and balances",
            onTap: _clearAllData,
          ),

          const SizedBox(height: 40),

          Center(
            child: Text(
              "Vault Money Manager • v$_appVersion",
              style: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surfaceBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
