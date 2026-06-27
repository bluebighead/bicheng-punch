import 'package:flutter/material.dart';

/// 主题状态管理
///
/// 通过 Provider 暴露主题模式，支持：
/// - 跟随系统
/// - 强制浅色（默认，避免新用户在系统为深色时看到不熟悉的深色界面）
/// - 强制深色
///
/// 当前仅占位实现，后续接入 SharedPreferences 持久化用户选择。
class ThemeProvider extends ChangeNotifier {
  // 默认浅色模式：保证首次进入时呈现稳定的浅色界面，
  // 不受系统主题影响，降低新用户认知成本
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
