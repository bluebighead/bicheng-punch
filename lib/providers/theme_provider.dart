import 'package:flutter/material.dart';

/// 主题状态管理
///
/// 通过 Provider 暴露主题模式，支持：
/// - 跟随系统（默认）
/// - 强制浅色
/// - 强制深色
///
/// 当前仅占位实现，后续接入 SharedPreferences 持久化用户选择。
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// 切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
