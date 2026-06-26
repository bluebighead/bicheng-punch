import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit_model.dart';

/// 桌面小组件数据服务
///
/// 负责从 Flutter 侧向桌面小组件推送数据。
/// 小组件显示今日待打卡习惯数量，点击可直接打开 APP（进入 Shell 主页）。
class WidgetService {
  WidgetService._();

  /// 小组件在 Android 端的 Provider 类名（需与 AndroidManifest 一致）
  static const String _widgetProviderName = 'HomeWidgetProvider';

  /// 初始化小组件 SDK
  static Future<void> init() async {
    try {
      // 注册小组件交互回调：点击小组件时跳转到 Shell 主页
      await HomeWidget.registerInteractivityCallback(interactivityCallback);
    } catch (e) {
      debugPrint('小组件初始化失败: $e');
    }
  }

  /// 更新小组件数据：今日待打卡习惯数量
  ///
  /// 在习惯列表或打卡记录发生变化时调用，确保小组件数据实时更新。
  static Future<void> updateWidgetData(List<Habit> habits) async {
    try {
      // 计算今日需打卡的习惯数量
      final today = DateTime.now();
      final pendingCount = habits.where((h) {
        if (!h.isActive) return false;
        return h.shouldCheckInOn(today);
      }).length;

      // 保存数据到 SharedPreferences（小组件通过 home_widget 读取）
      await HomeWidget.saveWidgetData<int>('pending_count', pendingCount);

      // 触发小组件刷新
      await HomeWidget.updateWidget(
        name: _widgetProviderName,
        iOSName: _widgetProviderName,
      );

      debugPrint('小组件数据已更新: $pendingCount 项待打卡');
    } catch (e) {
      debugPrint('更新小组件数据失败: $e');
    }
  }

  /// 仅刷新小组件（不更新数据）
  ///
  /// 在打卡记录变化时调用，保持小组件数据与当前状态一致。
  static Future<void> refreshWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: _widgetProviderName,
        iOSName: _widgetProviderName,
      );
    } catch (e) {
      debugPrint('刷新小组件失败: $e');
    }
  }

  /// 小组件交互回调：点击小组件后触发
  ///
  /// 默认不做额外导航，让系统直接打开 MainActivity 进入 Shell 主页。
  @pragma('vm:entry-point')
  static Future<void> interactivityCallback(Uri? uri) async {
    debugPrint('小组件交互回调: $uri');
    // 不需要额外导航，系统会自动打开 App 进入 Shell 主页
  }
}
