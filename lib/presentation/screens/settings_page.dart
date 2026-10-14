import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _dailyBudget = 500.0;
  int _snoozeDurationMinutes = 60;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadDailyBudget();
    _loadSnoozeDuration();
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

  Future<void> _loadDailyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble('daily_budget') ?? 500.0;
    if (mounted) {
      setState(() => _dailyBudget = savedBudget);
    }
  }

  Future<void> _updateDailyBudget(double newBudget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('daily_budget', newBudget);
    if (mounted) {
      setState(() => _dailyBudget = newBudget);
    }
  }

  Future<void> _loadSnoozeDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDuration = prefs.getInt('snooze_duration_minutes') ?? 60;
    if (mounted) {
      setState(() => _snoozeDurationMinutes = savedDuration);
    }
  }

  Future<void> _updateSnoozeDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snooze_duration_minutes', minutes);
    if (mounted) {
      setState(() => _snoozeDurationMinutes = minutes);
    }
  }

  String _formatSnoozeDuration(int minutes) {
    if (minutes < 60) {
      return "$minutes minutes";
    } else if (minutes == 60) {
      return "1 hour";
    } else {
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      if (remaining == 0) {
        return "$hours hours";
      }
      return "$hours hr $remaining min";
    }
  }

  void _showEditSnoozeDurationDialog() {
    int selected = _snoozeDurationMinutes;
    const options = [15, 30, 60, 120];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          title: "Snooze Duration",
          confirmLabel: "Save",
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((minutes) {
              final isSelected = minutes == selected;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  title: Text(
                    _formatSnoozeDuration(minutes),
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    setDialogState(() {
                      selected = minutes;
                    });
                  },
                ),
              );
            }).toList(),
          ),
          onConfirm: () {
            _updateSnoozeDuration(selected);
            Navigator.pop(context);
          },
        ),
      ),
    );
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
          keyboardType: TextInputType.number,
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

  Future<void> _clearAllData() async {
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: "Clear All Data?",
      message:
          "This will permanently delete all your expenses. Categories and wallet preferences will remain. This action cannot be undone.",
      confirmLabel: "Clear Data",
      confirmColor: AppColors.expense,
    );

    if (confirmed && mounted) {
      context.read<ExpenseBloc>().add(const ClearAllExpensesEvent());
      AppSnackBar.show(context, message: "All expense data cleared");
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
            subtitle: "Add, customize, or remove expense categories",
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
            title: "Snooze Duration",
            subtitle: _formatSnoozeDuration(_snoozeDurationMinutes),
            onTap: _showEditSnoozeDurationDialog,
          ),

          const SizedBox(height: 20),

          // Data & Storage
          const SectionHeader(title: "Data Management"),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.delete_outline_rounded,
            iconColor: AppColors.expense,
            title: "Clear All Data",
            subtitle: "Reset all local expenses",
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
