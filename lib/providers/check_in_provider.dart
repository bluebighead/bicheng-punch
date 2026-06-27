import 'package:flutter/material.dart';
import '../models/check_in_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'package:uuid/uuid.dart';

/// 打卡记录状态管理 Provider
///
/// 职责：
/// 1. 管理打卡记录（从 Hive 加载）
/// 2. 打卡/取消打卡操作
/// 3. 补签机制（额度管理）
/// 4. 休息日机制
/// 5. 历史打卡数据查询
class CheckInProvider extends ChangeNotifier {
  List<CheckIn> _checkIns = [];
  bool _isLoading = false;

  // ===== 计算结果缓存 =====
  // 主题切换/UI 重建时高频访问 isCheckedIn，原实现每次 .any() 遍历全部记录。
  // 缓存今日已打卡 habitId 集合，O(1) 查询。
  Set<String>? _todayCheckedHabitIdsCache;
  DateTime? _todayCacheDate;

  /// 数据变更回调：数据发生变化时触发（用于通知 LoginProvider 同步到服务器）
  VoidCallback? onDataChanged;

  /// 防抖锁：防止快速重复点击导致重复打卡
  bool _isCheckingIn = false;

  /// 获取所有打卡记录
  List<CheckIn> get checkIns => _checkIns;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 失效今日打卡缓存（数据变更时调用）
  void _invalidateTodayCache() {
    _todayCheckedHabitIdsCache = null;
    _todayCacheDate = null;
  }

  /// 获取今日已打卡的习惯 ID 集合（缓存）
  ///
  /// 性能优化：原 isCheckedIn 逐个 habit 调用 .any() 遍历全部 checkIns，
  /// N 个习惯 × M 条记录 = O(N*M)。
  /// 改为一次性构建今日打卡 Set，后续查询 O(1)。
  Set<String> getTodayCheckedHabitIds() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 缓存有效则直接返回
    if (_todayCheckedHabitIdsCache != null &&
        _todayCacheDate != null &&
        _todayCacheDate!.year == todayDate.year &&
        _todayCacheDate!.month == todayDate.month &&
        _todayCacheDate!.day == todayDate.day) {
      return _todayCheckedHabitIdsCache!;
    }

    // 重新构建缓存
    _todayCheckedHabitIdsCache = <String>{};
    _todayCacheDate = todayDate;
    for (final c in _checkIns) {
      if (c.date.year == todayDate.year &&
          c.date.month == todayDate.month &&
          c.date.day == todayDate.day) {
        _todayCheckedHabitIdsCache!.add(c.habitId);
      }
    }
    return _todayCheckedHabitIdsCache!;
  }

  /// 初始化：从 Hive 加载打卡记录
  Future<void> loadCheckIns() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = StorageService.checkInBox;
      _checkIns = box.values.toList();
      debugPrint('加载 ${_checkIns.length} 条打卡记录');
    } catch (e) {
      debugPrint('加载打卡记录失败: $e');
      _checkIns = [];
    }

    _isLoading = false;
    _invalidateTodayCache();
    notifyListeners();
  }

  /// 检查某习惯在某日期是否已打卡
  bool isCheckedIn(String habitId, DateTime date) {
    // 标准化日期（去掉时分秒）
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _checkIns.any((c) =>
        c.habitId == habitId &&
        c.date.year == normalizedDate.year &&
        c.date.month == normalizedDate.month &&
        c.date.day == normalizedDate.day);
  }

  /// 获取某习惯在某日期的打卡记录
  CheckIn? getCheckIn(String habitId, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _checkIns.firstWhereOrNull((c) =>
        c.habitId == habitId &&
        c.date.year == normalizedDate.year &&
        c.date.month == normalizedDate.month &&
        c.date.day == normalizedDate.day);
  }

  /// 打卡（今日或历史日期）
  ///
  /// 参数：
  /// - habitId：习惯 ID
  /// - date：打卡日期
  /// - note：备注（可选）
  /// - imagePath：图片路径（可选）
  /// - focusDuration：专注时长（可选）
  ///
  /// 返回值：
  /// - true：打卡成功
  /// - false：已打卡或补签额度不足
  Future<bool> checkIn(
    String habitId,
    DateTime date,
    String? note,
    String? imagePath,
    int? focusDuration,
  ) async {
    // 防抖：正在处理中则拒绝重复请求
    if (_isCheckingIn) {
      debugPrint('打卡操作进行中，忽略重复请求');
      return false;
    }
    _isCheckingIn = true;

    try {
      // 标准化日期
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final today = DateTime.now();
      final isToday = normalizedDate.year == today.year &&
          normalizedDate.month == today.month &&
          normalizedDate.day == today.day;

      // 检查是否已打卡
      if (isCheckedIn(habitId, normalizedDate)) {
        debugPrint('该日期已打卡，跳过');
        return false;
      }

      // 非今日打卡需要检查补签额度
      bool isMakeup = false;
      if (!isToday) {
        // 检查是否为休息日（休息日自动标记为完成，不算补签）
        if (StorageService.isRestDay(normalizedDate)) {
          debugPrint('休息日打卡，不计入补签');
        } else {
          // 使用补签额度
          if (!StorageService.useMakeupQuota()) {
            debugPrint('补签额度不足');
            return false;
          }
          isMakeup = true;
        }
      }

      final uuid = Uuid();
      final checkIn = CheckIn(
        id: uuid.v4(),
        habitId: habitId,
        date: normalizedDate,
        note: note,
        imagePath: imagePath,
        focusDuration: focusDuration,
        isMakeup: isMakeup,
        createdAt: DateTime.now(),
      );

      final box = StorageService.checkInBox;
      await box.put(checkIn.id, checkIn);
      _checkIns.add(checkIn);
      _invalidateTodayCache();
      notifyListeners();
      debugPrint('打卡成功: ${checkIn.id}');

      // 更新桌面小组件数据
      WidgetService.refreshWidget();
      onDataChanged?.call();

      return true;
    } catch (e) {
      debugPrint('打卡失败: $e');
      return false;
    } finally {
      _isCheckingIn = false;
    }
  }

  /// 取消打卡
  Future<void> cancelCheckIn(String checkInId) async {
    try {
      final box = StorageService.checkInBox;
      await box.delete(checkInId);
      _checkIns.removeWhere((c) => c.id == checkInId);
      _invalidateTodayCache();
      notifyListeners();
      onDataChanged?.call();
      debugPrint('取消打卡: $checkInId');
    } catch (e) {
      debugPrint('取消打卡失败: $e');
    }
  }

  /// 获取某日期的所有打卡记录
  List<CheckIn> getCheckInsByDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _checkIns.where((c) =>
        c.date.year == normalizedDate.year &&
        c.date.month == normalizedDate.month &&
        c.date.day == normalizedDate.day).toList();
  }

  /// 获取某习惯的所有打卡记录
  List<CheckIn> getCheckInsByHabit(String habitId) {
    return _checkIns.where((c) => c.habitId == habitId).toList();
  }

  /// 获取某习惯在某月的打卡天数
  int getMonthlyCheckInCount(String habitId, int year, int month) {
    return _checkIns.where((c) =>
        c.habitId == habitId &&
        c.date.year == year &&
        c.date.month == month).length;
  }

  /// 标记某日期为休息日
  Future<void> markRestDay(DateTime date, bool isRest) async {
    try {
      StorageService.setRestDay(date, isRest);
      notifyListeners();
      debugPrint('标记休息日: ${date.year}-${date.month}-${date.day} -> $isRest');
    } catch (e) {
      debugPrint('标记休息日失败: $e');
    }
  }

  /// 检查某日期是否为休息日
  bool isRestDay(DateTime date) {
    return StorageService.isRestDay(date);
  }

  /// 获取本月剩余补签额度
  int getRemainingMakeupQuota() {
    return StorageService.getMonthlyMakeupQuota();
  }

  // ===== 云同步：导出/导入 =====

  /// 将打卡记录导出为 JSON（用于上传到服务器）
  List<Map<String, dynamic>> exportToJson() {
    return _checkIns.map((c) => {
      'id': c.id,
      'habitId': c.habitId,
      'date': c.date.toIso8601String(),
      'note': c.note,
      'imagePath': c.imagePath,
      'focusDuration': c.focusDuration,
      'isMakeup': c.isMakeup,
      'createdAt': c.createdAt.toIso8601String(),
    }).toList();
  }

  /// 从 JSON 导入打卡记录（从服务器下载后合并到本地）
  Future<void> importFromJson(List<dynamic> jsonList) async {
    if (jsonList.isEmpty) return;

    final box = StorageService.checkInBox;
    int importedCount = 0;

    for (final item in jsonList) {
      try {
        final id = item['id'] as String;
        // 跳过已存在的记录
        if (_checkIns.any((c) => c.id == id)) continue;

        final checkIn = CheckIn(
          id: id,
          habitId: item['habitId'] as String,
          date: DateTime.parse(item['date'] as String),
          note: item['note'] as String?,
          imagePath: item['imagePath'] as String?,
          focusDuration: item['focusDuration'] as int?,
          isMakeup: item['isMakeup'] as bool? ?? false,
          createdAt: DateTime.parse(item['createdAt'] as String),
        );

        await box.put(checkIn.id, checkIn);
        _checkIns.add(checkIn);
        importedCount++;
      } catch (e) {
        debugPrint('导入打卡记录失败: $e');
      }
    }

    if (importedCount > 0) {
      _invalidateTodayCache();
      notifyListeners();
      debugPrint('从云端导入 $importedCount 条打卡记录');
    }
  }
}

/// List 扩展：firstWhereOrNull（避免 orElse 返回 null 的语法问题）
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}