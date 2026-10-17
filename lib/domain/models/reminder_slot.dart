import 'package:money_management_app/data/database/tables.dart';

class ReminderSlot {
  final int? id;
  final int categoryId;
  final String time; // HH:mm
  final int? defaultAmountCents; // NULL = fallback to the category's default_amount_cents
  final bool isActive;

  const ReminderSlot({
    this.id,
    required this.categoryId,
    required this.time,
    this.defaultAmountCents,
    this.isActive = true,
  });

  double get defaultAmount => (defaultAmountCents ?? 0) / 100.0;

  int effectiveAmountCents([int? fallbackCents]) =>
      defaultAmountCents ?? fallbackCents ?? 0;

  ReminderSlot copyWith({
    int? id,
    int? categoryId,
    String? time,
    int? defaultAmountCents,
    bool clearDefaultAmount = false,
    bool? isActive,
  }) {
    return ReminderSlot(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      time: time ?? this.time,
      defaultAmountCents: clearDefaultAmount ? null : (defaultAmountCents ?? this.defaultAmountCents),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) AppTables.colReminderId: id,
      AppTables.colReminderCategoryId: categoryId,
      AppTables.colReminderTime: time,
      AppTables.colReminderDefaultAmountCents: defaultAmountCents,
      AppTables.colReminderIsActive: isActive ? 1 : 0,
    };
  }

  factory ReminderSlot.fromMap(Map<String, dynamic> map) {
    return ReminderSlot(
      id: map[AppTables.colReminderId] as int?,
      categoryId: map[AppTables.colReminderCategoryId] as int,
      time: map[AppTables.colReminderTime] as String,
      defaultAmountCents: map[AppTables.colReminderDefaultAmountCents] as int?,
      isActive: (map[AppTables.colReminderIsActive] as int? ?? 1) == 1,
    );
  }
}
