import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_management_app/data/database/app_database.dart';
import 'package:money_management_app/data/datasources/app_settings_local_datasource.dart';
import 'package:money_management_app/data/datasources/category_local_datasource.dart';
import 'package:money_management_app/data/datasources/expense_local_datasource.dart';
import 'package:money_management_app/data/datasources/reminder_local_datasource.dart';
import 'package:money_management_app/data/datasources/transaction_local_datasource.dart';
import 'package:money_management_app/data/datasources/wallet_local_datasource.dart';
import 'package:money_management_app/data/repositories/category_repository_impl.dart';
import 'package:money_management_app/data/repositories/expense_repository_impl.dart';
import 'package:money_management_app/data/repositories/reminder_repository_impl.dart';
import 'package:money_management_app/data/repositories/settings_repository_impl.dart';
import 'package:money_management_app/data/repositories/transaction_repository_impl.dart';
import 'package:money_management_app/data/repositories/wallet_repository_impl.dart';
import 'package:money_management_app/domain/repositories/category_repository.dart';
import 'package:money_management_app/domain/repositories/expense_repository.dart';
import 'package:money_management_app/domain/repositories/reminder_repository.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';
import 'package:money_management_app/domain/repositories/transaction_repository.dart';
import 'package:money_management_app/domain/repositories/wallet_repository.dart';
import 'package:money_management_app/presentation/blocs/category/category_bloc.dart';
import 'package:money_management_app/presentation/blocs/category/category_event.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_bloc.dart';
import 'package:money_management_app/presentation/blocs/expense/expense_event.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_bloc.dart';
import 'package:money_management_app/presentation/blocs/reminder/reminder_event.dart';
import 'package:money_management_app/presentation/blocs/stats/stats_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_bloc.dart';
import 'package:money_management_app/presentation/blocs/wallet/wallet_event.dart';
import 'package:money_management_app/presentation/screens/add_transaction_page.dart';
import 'package:money_management_app/presentation/screens/main_shell.dart';
import 'package:money_management_app/presentation/screens/splash_screen.dart';
import 'package:money_management_app/presentation/screens/wallet_setup_page.dart';
import 'package:money_management_app/presentation/theme/app_colors.dart';
import 'package:money_management_app/services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool _isNavigatingToTransaction = false;

void handleNotificationPayload(String? payload) {
  NotificationService.log('handleNotificationPayload received payload: "$payload"');
  if (payload == null || payload.isEmpty) return;
  NotificationService.instance.clearPendingPayload();

  if (_isNavigatingToTransaction) {
    NotificationService.log('Already navigating to transaction screen; skipping duplicate navigation.');
    return;
  }

  try {
    final parts = payload.split('|');
    if (parts.isNotEmpty) {
      final categoryId = int.tryParse(parts[0]);
      final amountCents = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final double amount = amountCents / 100.0;

      _isNavigatingToTransaction = true;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => AddTransactionPage(
            initialCategoryId: categoryId,
            initialAmount: amount > 0 ? amount : null,
          ),
        ),
      ).then((_) {
        _isNavigatingToTransaction = false;
      });
    }
  } catch (e, st) {
    _isNavigatingToTransaction = false;
    NotificationService.log('Error handling notification payload: $e', error: e, stackTrace: st);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.log('main() entered: starting app initialization');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite Database instance
  final appDb = AppDatabase.instance;
  await appDb.database;

  // Initialize Notification Service
  try {
    await NotificationService.instance.initialize(
      onDidReceiveNotificationResponse: (response) {
        if (NotificationService.instance.isAppReadyForNavigation) {
          handleNotificationPayload(response.payload);
        } else {
          NotificationService.log(
            'Notification tapped while app was initializing; pending payload recorded.',
          );
        }
      },
    );
  } catch (e, st) {
    NotificationService.log('Error initializing NotificationService on startup: $e', error: e, stackTrace: st);
  }

  // Datasources
  final transactionDatasource = TransactionLocalDatasource(appDatabase: appDb);
  final expenseDatasource = ExpenseLocalDatasource(appDatabase: appDb);
  final categoryDatasource = CategoryLocalDatasource(appDatabase: appDb);
  final walletDatasource = WalletLocalDatasource(appDatabase: appDb);
  final reminderDatasource = ReminderLocalDatasource(appDatabase: appDb);
  final appSettingsDatasource = AppSettingsLocalDatasource(appDatabase: appDb);

  // Repositories
  final transactionRepository = TransactionRepositoryImpl(localDatasource: transactionDatasource);
  final expenseRepository = ExpenseRepositoryImpl(localDatasource: expenseDatasource);
  final categoryRepository = CategoryRepositoryImpl(localDatasource: categoryDatasource);
  final walletRepository = WalletRepositoryImpl(localDatasource: walletDatasource);
  final reminderRepository = ReminderRepositoryImpl(localDatasource: reminderDatasource);
  final settingsRepository = SettingsRepositoryImpl(localDatasource: appSettingsDatasource);

  // Re-sync all active daily reminders with the system alarm manager
  try {
    final activeReminders = await reminderRepository.getAllReminders();
    final categories = await categoryRepository.getAllCategories();
    NotificationService.log('Startup: Re-syncing ${activeReminders.length} reminders from repository');
    final catMap = {
      for (final c in categories)
        if (c.id != null) c.id!: c.name,
    };
    final catDefaults = {
      for (final c in categories)
        if (c.id != null) c.id!: c.defaultAmountCents,
    };
    await NotificationService.instance.rescheduleAllReminders(
      activeReminders,
      catMap,
      categoryDefaultAmounts: catDefaults,
    );
  } catch (e, st) {
    NotificationService.log('Error re-syncing reminders on startup: $e', error: e, stackTrace: st);
  }

  final isSetupDone = await settingsRepository.isWalletSetupDone();

  runApp(
    MyApp(
      transactionRepository: transactionRepository,
      expenseRepository: expenseRepository,
      categoryRepository: categoryRepository,
      walletRepository: walletRepository,
      reminderRepository: reminderRepository,
      settingsRepository: settingsRepository,
      isSetupDone: isSetupDone,
    ),
  );
}

class MyApp extends StatelessWidget {
  final TransactionRepository transactionRepository;
  final ExpenseRepository expenseRepository;
  final CategoryRepository categoryRepository;
  final WalletRepository walletRepository;
  final ReminderRepository reminderRepository;
  final SettingsRepository settingsRepository;
  final bool isSetupDone;
  final bool showSplash;

  const MyApp({
    super.key,
    required this.transactionRepository,
    required this.expenseRepository,
    required this.categoryRepository,
    required this.walletRepository,
    required this.reminderRepository,
    required this.settingsRepository,
    required this.isSetupDone,
    this.showSplash = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.isAppReadyForNavigation = true;
        final pending = NotificationService.instance.pendingPayload;
        if (pending != null) {
          handleNotificationPayload(pending);
        }
      });
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TransactionRepository>.value(value: transactionRepository),
        RepositoryProvider<ExpenseRepository>.value(value: expenseRepository),
        RepositoryProvider<CategoryRepository>.value(value: categoryRepository),
        RepositoryProvider<WalletRepository>.value(value: walletRepository),
        RepositoryProvider<ReminderRepository>.value(value: reminderRepository),
        RepositoryProvider<SettingsRepository>.value(value: settingsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExpenseBloc>(
            create: (context) => ExpenseBloc(
              transactionRepository: transactionRepository,
              expenseRepository: expenseRepository,
              categoryRepository: categoryRepository,
              walletRepository: walletRepository,
              settingsRepository: settingsRepository,
            )..add(const LoadExpenses()),
          ),
          BlocProvider<WalletBloc>(
            create: (context) => WalletBloc(
              walletRepository: walletRepository,
              expenseRepository: expenseRepository,
            )..add(const LoadWalletsEvent()),
          ),
          BlocProvider<StatsBloc>(
            create: (context) => StatsBloc(
              transactionRepository: transactionRepository,
              categoryRepository: categoryRepository,
              walletRepository: walletRepository,
              expenseRepository: expenseRepository,
            ),
          ),
          BlocProvider<CategoryBloc>(
            create: (context) => CategoryBloc(
              categoryRepository: categoryRepository,
            )..add(const LoadCategoriesEvent()),
          ),
          BlocProvider<ReminderBloc>(
            create: (context) => ReminderBloc(
              reminderRepository: reminderRepository,
              categoryRepository: categoryRepository,
            )..add(const LoadRemindersEvent()),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vault',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          home: showSplash
              ? const SplashScreen()
              : (isSetupDone ? const MainShell() : const WalletSetupPage()),
        ),
      ),
    );
  }
}
