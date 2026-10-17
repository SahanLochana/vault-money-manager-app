import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:money_management_app/domain/models/reminder_slot.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String logTag = 'NotificationService';

  static const String reminderChannelId = 'vault_expense_reminders_v2';
  static const String reminderChannelName = 'Expense Reminders';
  static const String reminderChannelDescription =
      'Daily expense reminders for meal and spending times';

  static const MethodChannel _intentChannel =
      MethodChannel('com.example.money_management_app/app_intent');

  bool _isInitialized = false;
  String? _pendingPayload;
  bool isAppReadyForNavigation = false;

  NotificationService._init();

  /// Standardized logging helper ensuring logs are recorded via [developer.log]
  /// with a consistent tag and also mirrored to stdout via [print] so they
  /// appear in Android Logcat under the `flutter` tag in release APKs.
  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: logTag,
      error: error,
      stackTrace: stackTrace,
    );
    final errStr = error != null ? ' | Error: $error' : '';
    final stackStr = stackTrace != null ? '\n$stackTrace' : '';
    // ignore: avoid_print
    print('[$logTag] $message$errStr$stackStr');
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, error: error, stackTrace: stackTrace);
  }

  String? get pendingPayload => _pendingPayload;

  void setPendingPayload(String? payload) {
    _pendingPayload = payload;
  }

  void clearPendingPayload() {
    _pendingPayload = null;
  }

  /// Queries the Android native MainActivity via MethodChannel to inspect the initial launch intent action.
  Future<String?> getInitialLaunchIntentAction() async {
    try {
      final action =
          await _intentChannel.invokeMethod<String>('getInitialIntentAction');
      _log('Platform initial launch intent action: $action');
      return action;
    } catch (e, st) {
      _log('Error querying initial launch intent action: $e', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> initialize({
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    if (_isInitialized) {
      _log('initialize() called but NotificationService is already initialized');
      return;
    }

    _log('initialize() started');

    // Check launch trigger from native Android intent
    final launchAction = await getInitialLaunchIntentAction();
    final isBoot = launchAction == 'android.intent.action.BOOT_COMPLETED' ||
        launchAction == 'android.intent.action.QUICKBOOT_POWERON' ||
        launchAction == 'com.htc.intent.action.QUICKBOOT_POWERON' ||
        launchAction == 'android.intent.action.MY_PACKAGE_REPLACED';
    final isUserTap = launchAction == 'android.intent.action.MAIN';
    _log(
      'App launch intent: action=$launchAction, isUserTap=$isUserTap, isBootTrigger=$isBoot',
    );

    try {
      tz.initializeTimeZones();

      _log('Resolving device timezone...');
      String resolvedTzName;
      try {
        final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
        resolvedTzName = tzInfo.identifier;
        _log('Platform resolved timezone identifier: "$resolvedTzName"');
      } catch (e, st) {
        _log('Error getting local timezone: $e, falling back to UTC', error: e, stackTrace: st);
        resolvedTzName = 'UTC';
      }

      try {
        final location = tz.getLocation(resolvedTzName);
        tz.setLocalLocation(location);
        _log('SUCCESS: Timezone set to location: "${location.name}" (currentTime: ${tz.TZDateTime.now(tz.local)})');
      } catch (e) {
        _log('Timezone location lookup failed for "$resolvedTzName", attempting offset match: $e');
        try {
          final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
          final matchingLocation = tz.timeZoneDatabase.locations.values
              .cast<tz.Location?>()
              .firstWhere((loc) {
                if (loc == null) return false;
                final nowInLoc = tz.TZDateTime.now(loc);
                return nowInLoc.timeZoneOffset.inMinutes == offsetMinutes;
              }, orElse: () => null);
          if (matchingLocation != null) {
            tz.setLocalLocation(matchingLocation);
            _log('SUCCESS: Timezone matched by offset fallback: "${matchingLocation.name}" (offset: ${offsetMinutes}m)');
          } else {
            _log('WARNING: No matching timezone location found by offset. Using default: "${tz.local.name}"');
          }
        } catch (e2, st2) {
          _log('Error matching timezone by offset: $e2', error: e2, stackTrace: st2);
        }
      }
    } catch (e, st) {
      _log('Timezone init error: $e', error: e, stackTrace: st);
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          _log(
            'onDidReceiveNotificationResponse: id=${response.id}, actionId=${response.actionId}, '
            'payload="${response.payload}", input=${response.input}, type=${response.notificationResponseType}',
          );
          if (response.payload != null && response.payload!.isNotEmpty) {
            _pendingPayload = response.payload;
          }
          if (onDidReceiveNotificationResponse != null) {
            onDidReceiveNotificationResponse(response);
          }
        },
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      _log('AndroidFlutterLocalNotificationsPlugin resolved: ${androidPlugin != null}');
      if (androidPlugin != null) {
        // Delete legacy channel if it exists to ensure new settings apply
        try {
          await androidPlugin.deleteNotificationChannel('meal_reminders_channel');
          _log('SUCCESS: Cleaned up legacy notification channel: meal_reminders_channel');
        } catch (e, st) {
          _log('Legacy channel delete check: $e', error: e, stackTrace: st);
        }

        // Create high-importance v2 channel with public lockscreen visibility
        try {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              reminderChannelId,
              reminderChannelName,
              description: reminderChannelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
          _log('SUCCESS: Created/updated notification channel "$reminderChannelId" (importance: max)');
        } catch (e, st) {
          _log('FAILURE: Failed to create notification channel "$reminderChannelId": $e', error: e, stackTrace: st);
        }
      }

      final details = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      _log(
        'getNotificationAppLaunchDetails: didNotificationLaunchApp=${details?.didNotificationLaunchApp}, '
        'id=${details?.notificationResponse?.id}, actionId=${details?.notificationResponse?.actionId}, '
        'payload="${details?.notificationResponse?.payload}"',
      );
      if (details != null && details.didNotificationLaunchApp) {
        if (details.notificationResponse?.payload != null) {
          _pendingPayload = details.notificationResponse!.payload;
          _log('App launched from notification with payload: $_pendingPayload');
        }
      }

      _isInitialized = true;
      _log('NotificationService initialized successfully (isInitialized=$_isInitialized)');
    } catch (e, st) {
      _log('Failed to initialize local notifications plugin: $e', error: e, stackTrace: st);
    }
  }

  Future<bool> hasNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      _log('hasNotificationPermission: status=$status (isGranted=${status.isGranted})');
      return status.isGranted;
    } catch (e, st) {
      _log('Error checking notification permission: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> isPermissionPermanentlyDenied() async {
    try {
      final status = await Permission.notification.isPermanentlyDenied;
      _log('isPermissionPermanentlyDenied: status=$status');
      return status;
    } catch (e, st) {
      _log('Error checking isPermissionPermanentlyDenied: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      _log('canScheduleExactAlarms: status=$status (isGranted=${status.isGranted})');
      return status.isGranted;
    } catch (e, st) {
      _log('Error checking scheduleExactAlarm status: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> requestExactAlarmsPermission() async {
    try {
      final before = await Permission.scheduleExactAlarm.status;
      _log('requestExactAlarmsPermission: before=$before');
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
      }
      final after = await Permission.scheduleExactAlarm.status;
      _log('requestExactAlarmsPermission: after=$after (isGranted=${after.isGranted})');
    } catch (e, st) {
      _log('Error requesting exact alarms permission: $e', error: e, stackTrace: st);
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      _log('isBatteryOptimizationIgnored: status=$status (isGranted=${status.isGranted})');
      return status.isGranted;
    } catch (e, st) {
      _log('Error checking ignoreBatteryOptimizations status: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final before = await Permission.ignoreBatteryOptimizations.status;
      _log('requestIgnoreBatteryOptimizations: before=$before');
      final requestResult = await Permission.ignoreBatteryOptimizations.request();
      final after = await Permission.ignoreBatteryOptimizations.status;
      _log('requestIgnoreBatteryOptimizations: requestResult=$requestResult, after=$after (isGranted=${after.isGranted})');
      return after.isGranted;
    } catch (e, st) {
      _log('Error requesting ignoreBatteryOptimizations: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> openSettings() async {
    _log('openSettings requested');
    try {
      final result = await openAppSettings();
      _log('openSettings result: $result');
      return result;
    } catch (e, st) {
      _log('Error opening app settings: $e', error: e, stackTrace: st);
      return false;
    }
  }

  /// Opens the Xiaomi/MIUI/HyperOS Autostart management screen so the user can
  /// enable autostart for this app.
  ///
  /// On non-Xiaomi devices all three MIUI-specific intents will throw and the
  /// native side falls back to ACTION_APPLICATION_DETAILS_SETTINGS, returning
  /// false to indicate the generic screen was opened instead.
  Future<bool> openAutostartSettings() async {
    _log('openAutostartSettings requested');
    try {
      final result =
          await _intentChannel.invokeMethod<bool>('openAutostartSettings');
      _log('openAutostartSettings result: $result');
      return result ?? false;
    } catch (e, st) {
      _log('Error opening autostart settings: $e', error: e, stackTrace: st);
      return false;
    }
  }

  /// Opens the Xiaomi/MIUI/HyperOS per-app battery saver screen.
  ///
  /// On non-Xiaomi devices the MIUI-specific intent will throw and the native
  /// side falls back to ACTION_APPLICATION_DETAILS_SETTINGS, returning false.
  Future<bool> openBatterySaverSettings() async {
    _log('openBatterySaverSettings requested');
    try {
      final result =
          await _intentChannel.invokeMethod<bool>('openBatterySaverSettings');
      _log('openBatterySaverSettings result: $result');
      return result ?? false;
    } catch (e, st) {
      _log('Error opening battery saver settings: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final before = await Permission.notification.status;
      _log('requestPermissions (notification): before=$before');

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final requestResult = await Permission.notification.request();
      final after = await Permission.notification.status;
      _log('requestPermissions (notification): requestResult=$requestResult, after=$after (isGranted=${after.isGranted})');
      return after.isGranted;
    } catch (e, st) {
      _log('Error in requestPermissions: $e', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> scheduleDailyReminder(
    ReminderSlot slot,
    String categoryName, {
    int? effectiveAmountCents,
  }) async {
    if (!slot.isActive || slot.id == null) {
      _log('scheduleDailyReminder skipped (isActive=${slot.isActive}, id=${slot.id})');
      return;
    }

    try {
      final notifGranted = await Permission.notification.isGranted;
      _log('scheduleDailyReminder slot #${slot.id} ($categoryName @ ${slot.time}): notifGranted=$notifGranted');
      if (!notifGranted) {
        _log('Cannot schedule reminder #${slot.id}: notification permission not granted');
        return;
      }

      // Re-verify exact alarm and battery optimization status right at schedule time
      final exactAlarmGranted = await canScheduleExactAlarms();
      final batteryOptIgnored = await isBatteryOptimizationIgnored();
      _log('Permissions at schedule instant for #${slot.id}: exactAlarmGranted=$exactAlarmGranted, batteryOptIgnored=$batteryOptIgnored');

      // Pre-cancel: cancel existing alarm for this slot ID before re-scheduling to avoid conflicting or duplicate alarms
      _log('PRE-CANCEL: Canceling any existing alarm for #${slot.id} before re-scheduling');
      await _notificationsPlugin.cancel(slot.id!);

      final parts = slot.time.split(':');
      if (parts.length != 2) {
        _log('Invalid time format for slot #${slot.id}: "${slot.time}"');
        return;
      }
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      final durationUntil = scheduledDate.difference(now);
      _log(
        'Computed scheduledDate for #${slot.id}: $scheduledDate '
        '(durationUntil: ${durationUntil.inHours}h ${durationUntil.inMinutes % 60}m ${durationUntil.inSeconds % 60}s, '
        '${durationUntil.inMilliseconds}ms total, local tz: ${tz.local.name})',
      );

      // Wall-clock vs tz accuracy comparison log
      final dartLocalNow = DateTime.now();
      final tzLocalNow = tz.TZDateTime.now(tz.local);
      _log(
        'TIME ACCURACY CHECK for #${slot.id}: '
        'Dart DateTime.now()=$dartLocalNow, '
        'tz.TZDateTime.now(tz.local)=$tzLocalNow, '
        'timezone=${tz.local.name}, '
        'offsetDiff=${dartLocalNow.timeZoneOffset.inMinutes - tzLocalNow.timeZoneOffset.inMinutes}min',
      );

      final int resolvedAmountCents =
          effectiveAmountCents ?? slot.defaultAmountCents ?? 0;
      final String amountStr = resolvedAmountCents > 0
          ? 'Rs ${(resolvedAmountCents / 100).toStringAsFixed(0)}'
          : '';
      final String notificationTitle = '$categoryName Reminder';
      final String notificationBody = amountStr.isNotEmpty
          ? 'Add expense: $amountStr?'
          : 'Ready to track your expense?';

      final bigTextStyleInformation = BigTextStyleInformation(
        amountStr.isNotEmpty
            ? '⚡ Time to log your expense!\nSuggested amount: $amountStr\nTap to record in 1 tap.'
            : 'Keep your budget on track by logging your expense.',
        contentTitle: notificationTitle,
        summaryText: 'Daily Reminder',
      );

      final androidDetails = AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: AppColors.primary,
        category: AndroidNotificationCategory.reminder,
        audioAttributesUsage: AudioAttributesUsage.notification,
        subText: 'Daily Reminder',
        ticker: 'Time to track your expense!',
        styleInformation: bigTextStyleInformation,
        vibrationPattern: Int64List.fromList([0, 50, 0, 50]),
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      final payload =
          '${slot.categoryId}|$resolvedAmountCents|${slot.id}';

      bool scheduled = false;

      if (exactAlarmGranted) {
        try {
          // alarmClock mode uses AlarmManager.setAlarmClock() which Android fully exempts
          // from Doze / App-Standby deferral — more reliable than exactAllowWhileIdle,
          // especially on MIUI / HyperOS devices.
          _log('ATTEMPT: Executing alarmClock zonedSchedule for slot #${slot.id} on channel $reminderChannelId at $scheduledDate');
          await _notificationsPlugin.zonedSchedule(
            slot.id!,
            notificationTitle,
            notificationBody,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          scheduled = true;
          _log('SUCCESS: Scheduled slot #${slot.id} with mode=AndroidScheduleMode.alarmClock');
        } catch (e, st) {
          _log('FAILURE: alarmClock zonedSchedule failed for slot #${slot.id}: $e', error: e, stackTrace: st);
        }
      } else {
        _log('SKIPPED: alarmClock skipped for slot #${slot.id} because exactAlarmGranted=false');
      }

      if (!scheduled) {
        _log(
          '⚠️ WARNING: Exact alarm not used for #${slot.id} (exactAlarmGranted=$exactAlarmGranted). '
          'Falling back to inexact mode. Notification timing may be delayed by up to 15+ minutes by Android Doze/battery optimization!',
        );
        try {
          _log('FALLBACK ATTEMPT: Executing inexactAllowWhileIdle zonedSchedule for slot #${slot.id} on channel $reminderChannelId at $scheduledDate');
          await _notificationsPlugin.zonedSchedule(
            slot.id!,
            notificationTitle,
            notificationBody,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          scheduled = true;
          _log('SUCCESS: Scheduled slot #${slot.id} with mode=AndroidScheduleMode.inexactAllowWhileIdle');
        } catch (e, st) {
          _log('FAILURE: inexactAllowWhileIdle failed for slot #${slot.id}: $e', error: e, stackTrace: st);
        }
      }

      // Post-schedule verification
      final pendingAlarms = await _notificationsPlugin.pendingNotificationRequests();
      final isRegistered = pendingAlarms.any((p) => p.id == slot.id!);
      final totalPending = pendingAlarms.length;
      _log(
        'POST-SCHEDULE VERIFICATION for #${slot.id}: '
        'isRegistered=$isRegistered, '
        'totalPendingAlarms=$totalPending, '
        'allPendingIds=[${pendingAlarms.map((p) => p.id).join(", ")}]',
      );
      if (!isRegistered) {
        _log('⚠️ CRITICAL: Alarm #${slot.id} was NOT found in pending notifications after scheduling!');
      }

      _log(
        'SCHEDULE SUMMARY for #${slot.id}: '
        'scheduled=$scheduled, '
        'mode=${exactAlarmGranted && scheduled ? "exactAllowWhileIdle" : (scheduled ? "inexactAllowWhileIdle" : "failed")}, '
        'scheduledDate=$scheduledDate, '
        'batteryOptIgnored=$batteryOptIgnored, '
        'channelId=$reminderChannelId',
      );
    } catch (e, st) {
      _log('Error in scheduleDailyReminder for slot #${slot.id}: $e', error: e, stackTrace: st);
    }
  }

  /// Debug helper: schedules a test notification [delaySeconds] into the future
  /// using the exact same zonedSchedule pipeline, channels, and error handling as [scheduleDailyReminder].
  Future<void> scheduleTestNotification({int delaySeconds = 30}) async {
    _log('scheduleTestNotification initiated (delay: ${delaySeconds}s)');
    try {
      final notifGranted = await hasNotificationPermission();
      _log('Test notification: notifGranted=$notifGranted');
      if (!notifGranted) {
        _log('Cannot schedule test notification: notification permission not granted');
        return;
      }

      // Pre-cancel test notification id 99999
      _log('PRE-CANCEL: Canceling any existing test notification (#99999)');
      await _notificationsPlugin.cancel(99999);

      final exactAlarmGranted = await canScheduleExactAlarms();
      final batteryOptIgnored = await isBatteryOptimizationIgnored();
      _log('Permissions at test schedule instant: exactAlarmGranted=$exactAlarmGranted, batteryOptIgnored=$batteryOptIgnored');

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(Duration(seconds: delaySeconds));
      final durationUntil = scheduledDate.difference(now);
      _log(
        'Computed scheduledDate for TEST notification (id=99999): $scheduledDate '
        '(durationUntil: ${durationUntil.inSeconds}s, ${durationUntil.inMilliseconds}ms total, local tz: ${tz.local.name})',
      );

      // Time accuracy check
      final dartLocalNow = DateTime.now();
      final tzLocalNow = tz.TZDateTime.now(tz.local);
      _log(
        'TIME ACCURACY CHECK for TEST notification: '
        'Dart DateTime.now()=$dartLocalNow, '
        'tz.TZDateTime.now(tz.local)=$tzLocalNow, '
        'timezone=${tz.local.name}, '
        'offsetDiff=${dartLocalNow.timeZoneOffset.inMinutes - tzLocalNow.timeZoneOffset.inMinutes}min',
      );

      const notificationTitle = '🧪 Test Reminder';
      const notificationBody = 'Test notification arrived on time!';

      const bigTextStyleInformation = BigTextStyleInformation(
        '⚡ Test notification successfully fired via zonedSchedule!\nPipeline validation complete.',
        contentTitle: notificationTitle,
        summaryText: 'Test Notification',
      );

      final androidDetails = AndroidNotificationDetails(
        reminderChannelId,
        reminderChannelName,
        channelDescription: reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: AppColors.primary,
        category: AndroidNotificationCategory.reminder,
        audioAttributesUsage: AudioAttributesUsage.notification,
        subText: 'Test Notification',
        ticker: 'Test notification triggered!',
        styleInformation: bigTextStyleInformation,
        vibrationPattern: Int64List.fromList([0, 50, 0, 50]),
      );
      final notificationDetails = NotificationDetails(android: androidDetails);
      const payload = 'TEST|0|99999';

      bool scheduled = false;

      if (exactAlarmGranted) {
        try {
          // alarmClock mode — Android exempts AlarmManager.setAlarmClock() from Doze entirely.
          _log('TEST ATTEMPT: Executing alarmClock zonedSchedule for test notification at $scheduledDate');
          await _notificationsPlugin.zonedSchedule(
            99999,
            notificationTitle,
            notificationBody,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          scheduled = true;
          _log('TEST SUCCESS: Scheduled test notification with mode=AndroidScheduleMode.alarmClock');
        } catch (e, st) {
          _log('TEST FAILURE: alarmClock zonedSchedule failed for test notification: $e', error: e, stackTrace: st);
        }
      } else {
        _log('TEST SKIPPED: alarmClock skipped for test notification because exactAlarmGranted=false');
      }

      if (!scheduled) {
        _log(
          '⚠️ WARNING: Exact alarm not used for test notification (exactAlarmGranted=$exactAlarmGranted). '
          'Falling back to inexact mode. Notification timing may be delayed by up to 15+ minutes!',
        );
        try {
          _log('FALLBACK TEST ATTEMPT: Executing inexactAllowWhileIdle zonedSchedule for test notification at $scheduledDate');
          await _notificationsPlugin.zonedSchedule(
            99999,
            notificationTitle,
            notificationBody,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          scheduled = true;
          _log('TEST SUCCESS: Scheduled test notification with fallback mode=AndroidScheduleMode.inexactAllowWhileIdle');
        } catch (e, st) {
          _log('TEST FAILURE: inexactAllowWhileIdle failed for test notification: $e', error: e, stackTrace: st);
        }
      }

      // Post-schedule verification
      final pendingAlarms = await _notificationsPlugin.pendingNotificationRequests();
      final isRegistered = pendingAlarms.any((p) => p.id == 99999);
      _log(
        'POST-SCHEDULE VERIFICATION for TEST notification: '
        'isRegistered=$isRegistered, '
        'totalPendingAlarms=${pendingAlarms.length}, '
        'allPendingIds=[${pendingAlarms.map((p) => p.id).join(", ")}]',
      );
      if (!isRegistered) {
        _log('⚠️ CRITICAL: Test alarm #99999 was NOT found in pending notifications after scheduling!');
      }
    } catch (e, st) {
      _log('Error in scheduleTestNotification: $e', error: e, stackTrace: st);
    }
  }

  Future<void> rescheduleAllReminders(
    List<ReminderSlot> slots,
    Map<int, String> categoryNames, {
    Map<int, int?>? categoryDefaultAmounts,
  }) async {
    _log('Rescheduling all ${slots.length} reminders...');
    int scheduledCount = 0;
    for (final slot in slots) {
      if (slot.isActive && slot.id != null) {
        final catName = categoryNames[slot.categoryId] ?? 'Expense Reminder';
        final effectiveAmount = slot.effectiveAmountCents(categoryDefaultAmounts?[slot.categoryId]);
        await scheduleDailyReminder(slot, catName, effectiveAmountCents: effectiveAmount);
        scheduledCount++;
      }
    }
    _log('Rescheduling complete: $scheduledCount active reminders processed out of ${slots.length}');

    try {
      final allPending = await _notificationsPlugin.pendingNotificationRequests();
      _log(
        'STARTUP AUDIT: ${allPending.length} alarms registered in AlarmManager after resync: '
        'ids=[${allPending.map((p) => "${p.id}:${p.title}").join(", ")}]',
      );
    } catch (e, st) {
      _log('STARTUP AUDIT ERROR: Failed to retrieve pending notification requests: $e', error: e, stackTrace: st);
    }
  }

  Future<void> scheduleReminder(
    ReminderSlot slot,
    String categoryName, {
    int? effectiveAmountCents,
  }) =>
      scheduleDailyReminder(
        slot,
        categoryName,
        effectiveAmountCents: effectiveAmountCents,
      );

  Future<void> cancelReminder(int id) async {
    try {
      _log('Canceling notification for reminder #$id');
      await _notificationsPlugin.cancel(id);
      _log('SUCCESS: Canceled notification for reminder #$id');
    } catch (e, st) {
      _log('Error canceling reminder #$id: $e', error: e, stackTrace: st);
    }
  }

  Future<void> cancelAllReminders() async {
    try {
      _log('Canceling all scheduled notifications');
      await _notificationsPlugin.cancelAll();
      _log('SUCCESS: Canceled all scheduled notifications');
    } catch (e, st) {
      _log('Error canceling all notifications: $e', error: e, stackTrace: st);
    }
  }
}
