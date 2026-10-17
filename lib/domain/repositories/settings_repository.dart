abstract class SettingsRepository {
  Future<double> getDailyBudget();
  Future<void> setDailyBudget(double budget);
  Future<int> getSnoozeDurationMinutes();
  Future<void> setSnoozeDurationMinutes(int minutes);
  Future<bool> isWalletSetupDone();
  Future<void> setWalletSetupDone(bool done);
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<Map<String, String>> getAllSettings();
}
