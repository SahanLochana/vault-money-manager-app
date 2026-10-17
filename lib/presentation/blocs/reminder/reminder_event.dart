import 'package:money_management_app/domain/models/reminder_slot.dart';

abstract class ReminderEvent {
  const ReminderEvent();
}

class LoadRemindersEvent extends ReminderEvent {
  const LoadRemindersEvent();
}

class AddReminderEvent extends ReminderEvent {
  final ReminderSlot slot;
  const AddReminderEvent(this.slot);
}

class UpdateReminderEvent extends ReminderEvent {
  final ReminderSlot slot;
  const UpdateReminderEvent(this.slot);
}

class DeleteReminderEvent extends ReminderEvent {
  final int id;
  const DeleteReminderEvent(this.id);
}

class ToggleReminderEvent extends ReminderEvent {
  final int id;
  final bool isActive;
  const ToggleReminderEvent({required this.id, required this.isActive});
}

class RescheduleAllRemindersEvent extends ReminderEvent {
  const RescheduleAllRemindersEvent();
}

class RemoveCategoryRemindersEvent extends ReminderEvent {
  final int categoryId;
  const RemoveCategoryRemindersEvent(this.categoryId);
}

