import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/reminder_repository.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_event.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_state.dart';
import 'package:money_management_app/services/notification_service.dart';

class ReminderBloc extends Bloc<ReminderEvent, ReminderState> {
  final ReminderRepository reminderRepository;
  final CategoryRepository categoryRepository;

  ReminderBloc({
    required this.reminderRepository,
    required this.categoryRepository,
  }) : super(const ReminderInitial()) {
    on<LoadRemindersEvent>(_onLoadReminders);
    on<AddReminderEvent>(_onAddReminder);
    on<UpdateReminderEvent>(_onUpdateReminder);
    on<DeleteReminderEvent>(_onDeleteReminder);
    on<ToggleReminderEvent>(_onToggleReminder);
    on<RescheduleAllRemindersEvent>(_onRescheduleAllReminders);
    on<RemoveCategoryRemindersEvent>(_onRemoveCategoryReminders);
  }

  Future<void> _onRemoveCategoryReminders(
    RemoveCategoryRemindersEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      final reminders = await reminderRepository.getAllReminders();
      for (final slot in reminders) {
        if (slot.categoryId == event.categoryId && slot.id != null) {
          await NotificationService.instance.cancelReminder(slot.id!);
          await reminderRepository.deleteReminder(slot.id!);
        }
      }
      add(const LoadRemindersEvent());
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onRemoveCategoryReminders error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onRescheduleAllReminders(
    RescheduleAllRemindersEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      NotificationService.log('ReminderBloc: _onRescheduleAllReminders triggered');
      final reminders = await reminderRepository.getAllReminders();
      final categories = await categoryRepository.getAllCategories();
      final catMap = {
        for (final c in categories)
          if (c.id != null) c.id!: c.name,
      };
      final catDefaults = {
        for (final c in categories)
          if (c.id != null) c.id!: c.defaultAmountCents,
      };
      await NotificationService.instance.rescheduleAllReminders(
        reminders,
        catMap,
        categoryDefaultAmounts: catDefaults,
      );
      emit(ReminderLoaded(reminders: reminders, categories: categories));
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onRescheduleAllReminders error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onLoadReminders(
    LoadRemindersEvent event,
    Emitter<ReminderState> emit,
  ) async {
    emit(const ReminderLoading());
    try {
      final reminders = await reminderRepository.getAllReminders();
      final categories = await categoryRepository.getAllCategories();
      NotificationService.log('ReminderBloc: _onLoadReminders loaded ${reminders.length} reminders');
      emit(ReminderLoaded(reminders: reminders, categories: categories));
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onLoadReminders error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onAddReminder(
    AddReminderEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      var slotToSave = event.slot;
      NotificationService.log('ReminderBloc: _onAddReminder for time=${slotToSave.time}, cat=${slotToSave.categoryId}');
      if (slotToSave.isActive) {
        final hasPerm = await NotificationService.instance.hasNotificationPermission();
        if (!hasPerm) {
          NotificationService.log('ReminderBloc: Disabling reminder on add because notification permission is false');
          slotToSave = slotToSave.copyWith(isActive: false);
        }
      }

      final id = await reminderRepository.addReminder(slotToSave);
      final cat = await categoryRepository.getCategoryById(slotToSave.categoryId);
      if (slotToSave.isActive) {
        final effectiveAmount = slotToSave.effectiveAmountCents(cat?.defaultAmountCents);
        await NotificationService.instance.scheduleReminder(
          slotToSave.copyWith(id: id),
          cat?.name ?? 'Expense Reminder',
          effectiveAmountCents: effectiveAmount,
        );
      }
      add(const LoadRemindersEvent());
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onAddReminder error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onUpdateReminder(
    UpdateReminderEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      var slotToUpdate = event.slot;
      NotificationService.log('ReminderBloc: _onUpdateReminder for slot #${slotToUpdate.id}');
      if (slotToUpdate.isActive) {
        final hasPerm = await NotificationService.instance.hasNotificationPermission();
        if (!hasPerm) {
          NotificationService.log('ReminderBloc: Disabling reminder on update because notification permission is false');
          slotToUpdate = slotToUpdate.copyWith(isActive: false);
        }
      }

      await reminderRepository.updateReminder(slotToUpdate);
      if (slotToUpdate.id != null) {
        final cat = await categoryRepository.getCategoryById(slotToUpdate.categoryId);
        if (slotToUpdate.isActive) {
          final effectiveAmount = slotToUpdate.effectiveAmountCents(cat?.defaultAmountCents);
          await NotificationService.instance.scheduleReminder(
            slotToUpdate,
            cat?.name ?? 'Expense Reminder',
            effectiveAmountCents: effectiveAmount,
          );
        } else {
          await NotificationService.instance.cancelReminder(slotToUpdate.id!);
        }
      }
      add(const LoadRemindersEvent());
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onUpdateReminder error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onDeleteReminder(
    DeleteReminderEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      NotificationService.log('ReminderBloc: _onDeleteReminder for slot #${event.id}');
      await NotificationService.instance.cancelReminder(event.id);
      await reminderRepository.deleteReminder(event.id);
      add(const LoadRemindersEvent());
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onDeleteReminder error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }

  Future<void> _onToggleReminder(
    ToggleReminderEvent event,
    Emitter<ReminderState> emit,
  ) async {
    try {
      bool targetActive = event.isActive;
      NotificationService.log('ReminderBloc: _onToggleReminder for slot #${event.id} targetActive=$targetActive');
      if (targetActive) {
        final hasPerm = await NotificationService.instance.hasNotificationPermission();
        if (!hasPerm) {
          NotificationService.log('ReminderBloc: Cannot toggle active because notification permission is false');
          targetActive = false;
        }
      }

      await reminderRepository.toggleReminder(event.id, targetActive);
      if (targetActive) {
        final reminders = await reminderRepository.getAllReminders();
        final slot = reminders.firstWhere((r) => r.id == event.id);
        final cat = await categoryRepository.getCategoryById(slot.categoryId);
        final effectiveAmount = slot.effectiveAmountCents(cat?.defaultAmountCents);
        await NotificationService.instance.scheduleReminder(
          slot,
          cat?.name ?? 'Expense Reminder',
          effectiveAmountCents: effectiveAmount,
        );
      } else {
        await NotificationService.instance.cancelReminder(event.id);
      }
      add(const LoadRemindersEvent());
    } catch (e, st) {
      NotificationService.log('ReminderBloc: _onToggleReminder error: $e', error: e, stackTrace: st);
      emit(ReminderError(e.toString()));
    }
  }
}
