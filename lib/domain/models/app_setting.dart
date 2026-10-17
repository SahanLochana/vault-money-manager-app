import 'package:money_management_app/data/database/tables.dart';

class AppSetting {
  final String key;
  final String value;

  const AppSetting({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      AppTables.colSettingKey: key,
      AppTables.colSettingValue: value,
    };
  }

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map[AppTables.colSettingKey] as String,
      value: map[AppTables.colSettingValue] as String,
    );
  }
}
