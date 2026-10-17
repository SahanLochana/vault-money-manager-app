import 'package:money_management_app/data/datasources/app_settings_local_datasource.dart';
import 'package:money_management_app/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final AppSettingsLocalDatasource localDatasource;

  SettingsRepositoryImpl({required this.localDatasource});

  static const String keyDailyBudget = 'daily_budget';
  static const String keySnoozeDurationMinutes = 'snooze_duration_minutes';
  static const String keyWalletSetupDone = 'wallet_setup_done';

  @override
  Future<double> getDailyBudget() async {
    return await localDatasource.getDouble(keyDailyBudget, 500.0);
  }

  @override
  Future<void> setDailyBudget(double budget) async {
    await localDatasource.setDouble(keyDailyBudget, budget);
  }

  @override
  Future<int> getSnoozeDurationMinutes() async {
    return await localDatasource.getInt(keySnoozeDurationMinutes, 15);
  }

  @override
  Future<void> setSnoozeDurationMinutes(int minutes) async {
    await localDatasource.setInt(keySnoozeDurationMinutes, minutes);
  }

  @override
  Future<bool> isWalletSetupDone() async {
    return await localDatasource.getBool(keyWalletSetupDone, false);
  }

  @override
  Future<void> setWalletSetupDone(bool done) async {
    await localDatasource.setBool(keyWalletSetupDone, done);
  }

  @override
  Future<String?> getSetting(String key) async {
    return await localDatasource.getSetting(key);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await localDatasource.setSetting(key, value);
  }

  @override
  Future<Map<String, String>> getAllSettings() async {
    return await localDatasource.getAllSettings();
  }
}
