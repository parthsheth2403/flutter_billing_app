import '../data/hive_database.dart';

class BillingSettings {
  BillingSettings._();

  static const String gstEnabledKey = 'gst_enabled';
  static const String gstRateKey = 'gst_rate';
  static const double defaultGstRate = 18;

  static bool get isGstEnabled =>
      HiveDatabase.settingsBox.get(gstEnabledKey, defaultValue: false) == true;

  static double get gstRate {
    final value = (HiveDatabase.settingsBox
            .get(gstRateKey, defaultValue: defaultGstRate) as num?)
        ?.toDouble();
    if (value == null || !value.isFinite || value < 0) {
      return defaultGstRate;
    }
    return value;
  }

  static Future<void> saveGstSettings({
    required bool enabled,
    required double rate,
  }) async {
    await HiveDatabase.settingsBox.put(gstEnabledKey, enabled);
    await HiveDatabase.settingsBox.put(
      gstRateKey,
      rate.isFinite && rate >= 0 ? rate : defaultGstRate,
    );
  }
}
