import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/hive/hive_registrar.dart';

class AppSettings {
  const AppSettings({
    this.currencySymbol = '₹',
    this.numberingFormat = 'Indian (Lakhs & Crores)',
    this.fiscalYearStartMonth = 4,
    this.gstEnabled = false,
    this.gstRate = 18.0,
    this.biometricEnabled = true,
  });

  final String currencySymbol;
  final String numberingFormat;
  final int fiscalYearStartMonth; // 1 = Jan, 4 = Apr
  final bool gstEnabled;
  final double gstRate;
  final bool biometricEnabled;

  AppSettings copyWith({
    String? currencySymbol,
    String? numberingFormat,
    int? fiscalYearStartMonth,
    bool? gstEnabled,
    double? gstRate,
    bool? biometricEnabled,
  }) {
    return AppSettings(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      numberingFormat: numberingFormat ?? this.numberingFormat,
      fiscalYearStartMonth: fiscalYearStartMonth ?? this.fiscalYearStartMonth,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstRate: gstRate ?? this.gstRate,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  String get fiscalYearLabel {
    switch (fiscalYearStartMonth) {
      case 1:
        return 'January 1 (Calendar Year)';
      case 4:
        return 'April 1 (Indian Financial Year)';
      case 7:
        return 'July 1';
      case 10:
        return 'October 1';
      default:
        return 'Month $fiscalYearStartMonth';
    }
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kCurrencyKey = 'app_currency_symbol';
  static const _kNumberingKey = 'app_numbering_format';
  static const _kFiscalMonthKey = 'app_fiscal_year_month';
  static const _kGstEnabledKey = 'app_gst_enabled';
  static const _kGstRateKey = 'app_gst_rate';
  static const _kBiometricEnabledKey = 'app_biometric_enabled';

  @override
  AppSettings build() {
    try {
      final box = HiveRegistrar.settingsBox;
      final currency = box.get(_kCurrencyKey) as String? ?? '₹';
      final numbering = box.get(_kNumberingKey) as String? ?? 'Indian (Lakhs & Crores)';
      final fiscalMonth = (box.get(_kFiscalMonthKey) as int?) ?? 4;
      final gstEnabled = (box.get(_kGstEnabledKey) as bool?) ?? false;
      final gstRate = (box.get(_kGstRateKey) as num?)?.toDouble() ?? 18.0;
      final biometricEnabled = (box.get(_kBiometricEnabledKey) as bool?) ?? true;

      return AppSettings(
        currencySymbol: currency,
        numberingFormat: numbering,
        fiscalYearStartMonth: fiscalMonth,
        gstEnabled: gstEnabled,
        gstRate: gstRate,
        biometricEnabled: biometricEnabled,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> setCurrencySymbol(String symbol) async {
    state = state.copyWith(currencySymbol: symbol);
    try {
      await HiveRegistrar.settingsBox.put(_kCurrencyKey, symbol);
    } catch (_) {}
  }

  Future<void> setNumberingFormat(String format) async {
    state = state.copyWith(numberingFormat: format);
    try {
      await HiveRegistrar.settingsBox.put(_kNumberingKey, format);
    } catch (_) {}
  }

  Future<void> setFiscalYearStartMonth(int month) async {
    state = state.copyWith(fiscalYearStartMonth: month);
    try {
      await HiveRegistrar.settingsBox.put(_kFiscalMonthKey, month);
    } catch (_) {}
  }

  Future<void> setGstEnabled(bool enabled) async {
    state = state.copyWith(gstEnabled: enabled);
    try {
      await HiveRegistrar.settingsBox.put(_kGstEnabledKey, enabled);
    } catch (_) {}
  }

  Future<void> setGstRate(double rate) async {
    state = state.copyWith(gstRate: rate);
    try {
      await HiveRegistrar.settingsBox.put(_kGstRateKey, rate);
    } catch (_) {}
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    try {
      await HiveRegistrar.settingsBox.put(_kBiometricEnabledKey, enabled);
    } catch (_) {}
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
