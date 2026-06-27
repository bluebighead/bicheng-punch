import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit_model.dart';
import '../models/check_in_model.dart';
import '../models/focus_record_model.dart';

/// 本地存储服务
///
/// 职责：
/// 1. 初始化 Hive 并注册 TypeAdapter
/// 2. 打开各类数据 Box
/// 3. 提供统一的 Box 访问入口，后续接入 Supabase 时便于替换实现
///
/// 容错：所有初始化均 try-catch，失败不崩溃，回退到内存态。
class StorageService {
  StorageService._();

  static late Box<Habit> _habitBox; // 习惯定义
  static late Box<CheckIn> _checkInBox; // 打卡记录
  static late Box _configBox; // 用户配置（补签额度、休息日、备考类型等）
  static late Box<FocusRecord> _focusRecordBox; // 专注记录

  static bool _initialized = false;

  /// 是否已初始化完成
  static bool get isInitialized => _initialized;

  /// 全局初始化：在 runApp 前调用
  static Future<void> init() async {
    try {
      await Hive.initFlutter();

      // 注册 TypeAdapter（必须先注册再打开 Box）
      Hive.registerAdapter(HabitAdapter());
      Hive.registerAdapter(CheckInAdapter());
      // 注册专注记录 TypeAdapter
      Hive.registerAdapter(FocusRecordAdapter());

      // 打开各数据 Box
      _habitBox = await Hive.openBox<Habit>('habit_box');
      _checkInBox = await Hive.openBox<CheckIn>('checkin_box');
      _configBox = await Hive.openBox('config_box');
      _focusRecordBox = await Hive.openBox<FocusRecord>('focus_record_box');

      debugPrint('StorageService 初始化成功');
    } catch (e) {
      debugPrint('Hive 初始化失败，回退内存态: $e');
      // 回退：打开内存盒子，保证不崩溃
      try {
        _habitBox = await Hive.openBox<Habit>('habit_box_memory');
        _checkInBox = await Hive.openBox<CheckIn>('checkin_box_memory');
        _configBox = await Hive.openBox('config_box_memory');
        _focusRecordBox = await Hive.openBox<FocusRecord>('focus_record_box_memory');
      } catch (e2) {
        debugPrint('内存态 Box 打开失败: $e2');
      }
    }

    _initialized = true;
  }

  /// 习惯定义 Box
  static Box<Habit> get habitBox => _habitBox;

  /// 打卡记录 Box
  static Box<CheckIn> get checkInBox => _checkInBox;

  /// 用户配置 Box
  static Box get configBox => _configBox;

  /// 专注记录 Box
  static Box<FocusRecord> get focusRecordBox => _focusRecordBox;

  // ===== 配置相关便捷方法 =====

  /// 获取本月补签剩余额度（默认每月 3 次）
  ///
  /// 每月自动重置为 3 次，防止跨月累积
  static int getMonthlyMakeupQuota() {
    final now = DateTime.now();
    final currentKey = 'makeup_quota_${now.year}_${now.month}';

    // 清理历史月份的补签额度，防止无限累积
    try {
      final allKeys = _configBox.keys;
      for (final key in allKeys) {
        if (key is String &&
            key.startsWith('makeup_quota_') &&
            key != currentKey) {
          _configBox.delete(key);
        }
      }
    } catch (e) {
      debugPrint('清理历史补签额度失败: $e');
    }

    return _configBox.get(currentKey, defaultValue: 3) as int;
  }

  /// 设置本月补签额度
  static void setMonthlyMakeupQuota(int quota) {
    final key = 'makeup_quota_${DateTime.now().year}_${DateTime.now().month}';
    try {
      _configBox.put(key, quota);
    } catch (e) {
      debugPrint('设置补签额度失败: $e');
    }
  }

  /// 使用一次补签额度
  static bool useMakeupQuota() {
    final current = getMonthlyMakeupQuota();
    if (current <= 0) return false;
    setMonthlyMakeupQuota(current - 1);
    return true;
  }

  /// 检查某日期是否为休息日
  static bool isRestDay(DateTime date) {
    final key = 'rest_day_${date.year}_${date.month}_${date.day}';
    return _configBox.get(key, defaultValue: false) as bool;
  }

  /// 设置某日期为休息日
  static void setRestDay(DateTime date, bool isRest) {
    final key = 'rest_day_${date.year}_${date.month}_${date.day}';
    try {
      _configBox.put(key, isRest);
    } catch (e) {
      debugPrint('设置休息日失败: $e');
    }
  }

  // ===== 白名单应用相关 =====

  /// 读取白名单应用列表
  ///
  /// 返回持久化的白名单应用列表，未设置时返回空列表。
  /// 上限由 UI 层约束（3 个），存储层不强制。
  static List<Map<String, dynamic>> getWhitelistApps() {
    try {
      final raw = _configBox.get('whitelist_apps');
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('读取白名单应用失败: $e');
      return [];
    }
  }

  /// 写入白名单应用列表
  ///
  /// [apps] 为待持久化的白名单应用 JSON 列表
  static void setWhitelistApps(List<Map<String, dynamic>> apps) {
    try {
      _configBox.put('whitelist_apps', apps);
    } catch (e) {
      debugPrint('写入白名单应用失败: $e');
    }
  }
}