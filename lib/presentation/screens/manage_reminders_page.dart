import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/models/category.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/presentation/blocs/category/category_bloc.dart';
import 'package:money_management_app/presentation/blocs/category/category_event.dart';
import 'package:money_management_app/presentation/blocs/category/category_state.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_bloc.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_event.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_state.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/presentation/widgets/app_back_appbar.dart';
import 'package:money_management_app/presentation/widgets/app_dialog_shell.dart';
import 'package:money_management_app/presentation/widgets/app_loading_indicator.dart';
import 'package:money_management_app/presentation/widgets/app_snackbar.dart';
import 'package:money_management_app/presentation/widgets/app_text_field.dart';
import 'package:money_management_app/presentation/widgets/confirm_action_dialog.dart';
import 'package:money_management_app/presentation/widgets/info_banner_card.dart';
import 'package:money_management_app/presentation/widgets/labeled_field.dart';
import 'package:money_management_app/presentation/widgets/pill_action_button.dart';
import 'package:money_management_app/presentation/widgets/reminder_card.dart';
import 'package:money_management_app/services/notification_service.dart';

class ManageRemindersPage extends StatefulWidget {
  const ManageRemindersPage({super.key});

  @override
  State<ManageRemindersPage> createState() => _ManageRemindersPageState();
}

class _ManageRemindersPageState extends State<ManageRemindersPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CategoryBloc>().add(const LoadCategoriesEvent());
    context.read<ReminderBloc>().add(const LoadRemindersEvent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsOnResume();
    }
  }

  Future<void> _checkPermissionsOnResume() async {
    final notifGranted =
        await NotificationService.instance.hasNotificationPermission();
    final exactAlarmGranted =
        await NotificationService.instance.canScheduleExactAlarms();
    final batteryIgnored =
        await NotificationService.instance.isBatteryOptimizationIgnored();

    NotificationService.log(
      'Lifecycle RESUMED (_checkPermissionsOnResume): '
      'notificationGranted=$notifGranted, '
      'exactAlarmGranted=$exactAlarmGranted, '
      'batteryOptimizationIgnored=$batteryIgnored',
    );

    if (!mounted) return;
    if (notifGranted) {
      context.read<ReminderBloc>().add(const RescheduleAllRemindersEvent());
    } else {
      context.read<ReminderBloc>().add(const LoadRemindersEvent());
    }
  }

  Future<void> _ensureBatteryOptimization() async {
    final isIgnored =
        await NotificationService.instance.isBatteryOptimizationIgnored();
    NotificationService.log(
      '_ensureBatteryOptimization: isBatteryOptimizationIgnored=$isIgnored',
    );
    if (isIgnored || !mounted) return;

    final allowed = await ConfirmActionDialog.show(
      context,
      title: "Background Reliability",
      titleIcon: Icons.battery_saver_rounded,
      titleIconColor: AppColors.warning,
      message:
          "To make sure your scheduled reminders arrive on time when the app is in the background, please disable battery optimization for Vault.",
      cancelLabel: "Not Now",
      confirmLabel: "Allow",
      confirmColor: AppColors.primary,
      confirmTextColor: const Color(0xFF0F0F14),
    );

    if (allowed) {
      final reqResult =
          await NotificationService.instance.requestIgnoreBatteryOptimizations();
      NotificationService.log(
        '_ensureBatteryOptimization: user allowed dialog, requestIgnoreBatteryOptimizations result=$reqResult',
      );

      // Show a follow-up Autostart dialog.
      //
      // Some phone manufacturers (notably Xiaomi, Redmi and POCO running MIUI /
      // HyperOS) maintain a separate "Autostart" allowlist that is completely
      // independent of Android's standard battery-optimisation API. If the app
      // is not in that allowlist, the OS silently cancels all scheduled alarms
      // the moment the app is swiped away — no standard permission covers this.
      //
      // We show the dialog unconditionally because:
      //   • On Xiaomi devices: the native call opens the real Autostart screen.
      //   • On all other devices: the native call gracefully falls back to the
      //     generic app-info screen (returns false) without crashing.
      //
      // NOTE: If device_info_plus is added as a dependency in the future, gate
      // this dialog on `(await DeviceInfoPlugin().androidInfo).manufacturer
      // .toLowerCase().contains('xiaomi')` to avoid showing an irrelevant extra
      // step to Samsung/Pixel/OnePlus users.
      if (!mounted) return;
      final autostartAllowed = await ConfirmActionDialog.show(
        context,
        title: "One More Step for Reliable Reminders",
        titleIcon: Icons.auto_awesome_rounded,
        titleIconColor: AppColors.primary,
        message:
            "Your phone's manufacturer sometimes needs an extra permission called \"Autostart\" to let scheduled reminders fire in the background. Tap Allow to open the relevant settings screen.",
        cancelLabel: "Skip",
        confirmLabel: "Allow",
        confirmColor: AppColors.primary,
        confirmTextColor: const Color(0xFF0F0F14),
      );

      if (autostartAllowed) {
        final launched =
            await NotificationService.instance.openAutostartSettings();
        NotificationService.log(
          '_ensureBatteryOptimization: openAutostartSettings launched=$launched',
        );
      } else {
        NotificationService.log(
          '_ensureBatteryOptimization: user skipped Autostart dialog',
        );
      }
    } else {
      NotificationService.log(
        '_ensureBatteryOptimization: user dismissed background reliability dialog',
      );
    }
  }

  Future<bool> _ensureNotificationPermission() async {
    final granted =
        await NotificationService.instance.hasNotificationPermission();
    NotificationService.log(
      '_ensureNotificationPermission: initial notificationGranted=$granted',
    );
    if (granted) {
      final exactGranted =
          await NotificationService.instance.canScheduleExactAlarms();
      NotificationService.log(
        '_ensureNotificationPermission: exactGranted=$exactGranted',
      );
      if (!exactGranted) {
        await NotificationService.instance.requestExactAlarmsPermission();
      }
      await _ensureBatteryOptimization();
      return true;
    }
    if (!mounted) return false;

    final allowed = await ConfirmActionDialog.show(
      context,
      title: "Notifications Disabled",
      message:
          "To receive your daily spending reminders, please enable notifications.",
      cancelLabel: "Not Now",
      confirmLabel: "Allow",
      confirmColor: AppColors.primary,
      confirmTextColor: const Color(0xFF0F0F14),
    );

    if (allowed) {
      final reqGranted =
          await NotificationService.instance.requestPermissions();
      NotificationService.log(
        '_ensureNotificationPermission: user allowed dialog, requestPermissions result=$reqGranted',
      );
      if (reqGranted) {
        final exactGranted =
            await NotificationService.instance.canScheduleExactAlarms();
        NotificationService.log(
          '_ensureNotificationPermission: after requestPermissions, exactGranted=$exactGranted',
        );
        if (!exactGranted) {
          await NotificationService.instance.requestExactAlarmsPermission();
        }
        await _ensureBatteryOptimization();
        if (mounted) {
          context.read<ReminderBloc>().add(
            const RescheduleAllRemindersEvent(),
          );
        }
        return true;
      } else {
        final permDenied =
            await NotificationService.instance.isPermissionPermanentlyDenied();
        NotificationService.log(
          '_ensureNotificationPermission: permission permanently denied = $permDenied',
        );
        if (permDenied) {
          await NotificationService.instance.openSettings();
        }
      }
    } else {
      NotificationService.log(
        '_ensureNotificationPermission: user dismissed notification permission dialog',
      );
    }
    return false;
  }

  Future<void> _addReminderDialog() async {
    final catState = context.read<CategoryBloc>().state;
    final List<Category> categories =
        (catState is CategoryLoaded) ? catState.categories : <Category>[];

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please add a category first"),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    int selectedCatId = categories.first.id ?? 1;
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
    final amountCtrl = TextEditingController();

    final created = await showDialog<ReminderSlot>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogShell(
          title: "Add Daily Reminder",
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledField(
                  label: "Category",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedCatId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: categories.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Row(
                              children: [
                                Text(
                                  c.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedCatId = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Reminder Time",
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary,
                                surface: AppColors.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            "Change",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: "Default Amount (Optional)",
                  child: AppTextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    hintText: "0.00",
                    prefixText: "Rs ",
                  ),
                ),
              ],
            ),
          ),
          onConfirm: () {
            final amt = double.tryParse(amountCtrl.text.trim());
            final timeStr =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
            Navigator.pop(
              context,
              ReminderSlot(
                categoryId: selectedCatId,
                time: timeStr,
                defaultAmountCents: (amt != null && amt > 0) ? (amt * 100).toInt() : null,
                isActive: true,
              ),
            );
          },
        ),
      ),
    );

    if (created != null && mounted) {
      final allowed = await _ensureNotificationPermission();
      final slotToAdd = allowed ? created : created.copyWith(isActive: false);
      if (mounted) {
        context.read<ReminderBloc>().add(AddReminderEvent(slotToAdd));
        AppSnackBar.show(
          context,
          message: allowed
              ? "Reminder added"
              : "Reminder added (toggled off until notifications are allowed)",
        );
      }
    }
  }

  Future<void> _editReminderTime(ReminderSlot slot) async {
    final parts = slot.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 12,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      var updated = slot.copyWith(time: timeStr);
      if (updated.isActive) {
        final allowed = await _ensureNotificationPermission();
        if (!allowed) {
          updated = updated.copyWith(isActive: false);
        }
      }
      if (mounted) {
        context.read<ReminderBloc>().add(UpdateReminderEvent(updated));
      }
    }
  }

  Future<void> _toggleReminder(ReminderSlot slot, bool val) async {
    if (val) {
      final allowed = await _ensureNotificationPermission();
      if (!allowed) {
        if (mounted) setState(() {});
        return;
      }
    }
    if (slot.id != null && mounted) {
      context.read<ReminderBloc>().add(
        ToggleReminderEvent(id: slot.id!, isActive: val),
      );
    }
  }

  Future<void> _deleteReminderDialog(ReminderSlot slot, String title) async {
    final confirmed = await ConfirmActionDialog.show(
      context,
      title: "Delete Reminder?",
      message: "Are you sure you want to delete the '$title' at ${slot.time}?",
      confirmLabel: "Delete",
      confirmColor: AppColors.expense,
    );

    if (confirmed && mounted && slot.id != null) {
      context.read<ReminderBloc>().add(DeleteReminderEvent(slot.id!));
      AppSnackBar.show(context, message: "Deleted '$title'");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBackAppBar(
        title: "Daily Reminders",
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PillActionButton(
              label: "Add",
              icon: Icons.add_rounded,
              color: AppColors.primary,
              onPressed: _addReminderDialog,
            ),
          ),
        ],
      ),
      body: BlocBuilder<ReminderBloc, ReminderState>(
        builder: (context, state) {
          if (state is ReminderLoading) {
            return const AppLoadingIndicator();
          }

          if (state is ReminderLoaded) {
            final activeCount = state.reminders.where((r) => r.isActive).length;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Info Banner
                InfoBannerCard(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.primary,
                  iconSize: 22,
                  iconBgColor: AppColors.primary.withValues(alpha: 0.2),
                  title:
                      "$activeCount Active Reminder${activeCount == 1 ? '' : 's'}",
                  subtitle: "Tap any card to quickly adjust notification time",
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),


                if (state.reminders.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.surfaceBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textMuted,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No Reminders Scheduled",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Set scheduled alerts to log your expenses at key times throughout the day.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _addReminderDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              "Add First Reminder",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF0F0F14),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.reminders.map((slot) {
                    final cat = state.getCategory(slot.categoryId);
                    final title =
                        '${cat?.emoji ?? "⏰"} ${cat?.name ?? "Meal"} Reminder';

                    return ReminderCard(
                      title: title,
                      time: slot.time,
                      value: slot.isActive,
                      onChanged: (val) => _toggleReminder(slot, val),
                      onTimeTap: () => _editReminderTime(slot),
                      onDelete: () => _deleteReminderDialog(slot, title),
                    );
                  }),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
