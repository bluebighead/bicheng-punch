import 'package:flutter/material.dart';
import '../models/habit_model.dart';
import '../services/storage_service.dart';
import '../services/template_service.dart';
import '../services/widget_service.dart';

/// 习惯状态管理 Provider
///
/// 职责：
/// 1. 管理习惯列表（从 Hive 加载）
/// 2. 添加/删除/更新习惯
/// 3. 一键添加备考模板习惯
/// 4. 提供今日需打卡的习惯列表
class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  bool _isLoading = false;

  // ===== 计算结果缓存 =====
  // 主题切换/UI 重建时高频访问 activeHabits 和 getTodayHabits()，
  // 原实现每次都 filter+toList 创建新列表，数据多时累积开销明显。
  // 缓存后仅在数据变更（增删改/加载）时失效重算。
  List<Habit>? _activeHabitsCache;
  List<Habit>? _todayHabitsCache;

  /// 数据变更回调：数据发生变化时触发（用于通知 LoginProvider 同步到服务器）
  VoidCallback? onDataChanged;

  /// 失效计算缓存（数据变更时调用）
  void _invalidateCache() {
    _activeHabitsCache = null;
    _todayHabitsCache = null;
  }

  /// 获取所有习惯列表
  List<Habit> get habits => _habits;

  /// 获取启用的习惯列表（缓存：避免每次 build 重复 filter）
  List<Habit> get activeHabits =>
      _activeHabitsCache ??=
          _habits.where((h) => h.isActive).toList();

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 初始化：从 Hive 加载习惯数据
  Future<void> loadHabits() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = StorageService.habitBox;
      _habits = box.values.toList();
      debugPrint('加载 ${_habits.length} 个习惯');
    } catch (e) {
      debugPrint('加载习惯失败: $e');
      _habits = [];
    }

    _isLoading = false;
    _invalidateCache();
    notifyListeners();

    // 更新桌面小组件数据
    WidgetService.updateWidgetData(_habits);
  }

  /// 获取今日需打卡的习惯列表（缓存：避免每次 build 重复 filter）
  ///
  /// 过滤规则：
  /// 1. 习惯需启用（isActive）
  /// 2. 根据打卡频率规则判断今日是否需要打卡
  List<Habit> getTodayHabits() {
    if (_todayHabitsCache != null) return _todayHabitsCache!;
    final today = DateTime.now();
    _todayHabitsCache = activeHabits.where((h) => h.shouldCheckInOn(today)).toList();
    return _todayHabitsCache!;
  }

  /// 添加单个习惯
  Future<void> addHabit(Habit habit) async {
    try {
      final box = StorageService.habitBox;
      await box.put(habit.id, habit);
      _habits.add(habit);
      _invalidateCache();
      notifyListeners();
      debugPrint('添加习惯: ${habit.name}');

      // 更新桌面小组件数据
      WidgetService.updateWidgetData(_habits);
      onDataChanged?.call();
    } catch (e) {
      debugPrint('添加习惯失败: $e');
    }
  }

  /// 一键添加备考模板（批量添加）
  Future<void> addTemplatesFromCategory(ExamCategory category) async {
    final templates = TemplateService.getTemplatesByCategory(category);
    for (final template in templates) {
      final id = '${category.name}_${DateTime.now().millisecondsSinceEpoch}_${template.name.hashCode}';
      final habit = TemplateService.templateToHabit(template, id);
      await addHabit(habit);
    }
    debugPrint('批量添加 ${templates.length} 个模板习惯');
  }

  /// 删除习惯
  Future<void> removeHabit(String habitId) async {
    try {
      final box = StorageService.habitBox;
      await box.delete(habitId);
      _habits.removeWhere((h) => h.id == habitId);
      _invalidateCache();
      notifyListeners();
      debugPrint('删除习惯: $habitId');

      // 更新桌面小组件数据
      WidgetService.updateWidgetData(_habits);
      onDataChanged?.call();
    } catch (e) {
      debugPrint('删除习惯失败: $e');
    }
  }

  /// 更新习惯状态（启用/禁用）
  Future<void> updateHabitActive(String habitId, bool isActive) async {
    try {
      final index = _habits.indexWhere((h) => h.id == habitId);
      if (index == -1) return;

      // Hive 中存储的对象不可直接修改，需要创建新对象替换
      final oldHabit = _habits[index];
      final newHabit = Habit(
        id: oldHabit.id,
        name: oldHabit.name,
        icon: oldHabit.icon,
        color: oldHabit.color,
        examCategory: oldHabit.examCategory,
        customCategory: oldHabit.customCategory,
        frequencyType: oldHabit.frequencyType,
        weeklyCount: oldHabit.weeklyCount,
        customDays: oldHabit.customDays,
        createdAt: oldHabit.createdAt,
        isActive: isActive,
      );

      final box = StorageService.habitBox;
      await box.put(habitId, newHabit);
      _habits[index] = newHabit;
      _invalidateCache();
      notifyListeners();

      // 更新桌面小组件数据
      WidgetService.updateWidgetData(_habits);
      onDataChanged?.call();
    } catch (e) {
      debugPrint('更新习惯状态失败: $e');
    }
  }

  /// 根据 ID 获取习惯
  Habit? getHabitById(String habitId) {
    for (final habit in _habits) {
      if (habit.id == habitId) return habit;
    }
    return null;
  }

  /// 批量设置自定义分类组
  ///
  /// 将 [habitIds] 中所有自定义习惯（examCategory == custom）的 customCategory
  /// 设置为 [categoryName]。传入 null 或空字符串则将其重置回默认「自定义」组。
  ///
  /// 注意：仅自定义习惯会被修改，模板习惯（考研/考公等）不受影响。
  Future<void> setCustomCategoryForHabits(
    List<String> habitIds,
    String? categoryName,
  ) async {
    final trimmed = categoryName?.trim();
    final target = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final box = StorageService.habitBox;
    int updatedCount = 0;

    for (final id in habitIds) {
      final index = _habits.indexWhere((h) => h.id == id);
      if (index == -1) continue;

      final oldHabit = _habits[index];
      // 仅自定义习惯可被重新分组
      if (oldHabit.examCategory != ExamCategory.custom) continue;
      // 若值未变化则跳过
      if (oldHabit.customCategory == target) continue;

      final newHabit = Habit(
        id: oldHabit.id,
        name: oldHabit.name,
        icon: oldHabit.icon,
        color: oldHabit.color,
        examCategory: oldHabit.examCategory,
        customCategory: target,
        frequencyType: oldHabit.frequencyType,
        weeklyCount: oldHabit.weeklyCount,
        customDays: oldHabit.customDays,
        createdAt: oldHabit.createdAt,
        isActive: oldHabit.isActive,
      );

      await box.put(id, newHabit);
      _habits[index] = newHabit;
      updatedCount++;
    }

    if (updatedCount > 0) {
      _invalidateCache();
      notifyListeners();
      WidgetService.updateWidgetData(_habits);
      onDataChanged?.call();
      debugPrint('已为 $updatedCount 个习惯设置分类组: $target');
    }
  }

  // ===== 云同步：导出/导入 =====

  /// 将习惯列表导出为 JSON（用于上传到服务器）
  List<Map<String, dynamic>> exportToJson() {
    return _habits.map((h) => {
      'id': h.id,
      'name': h.name,
      'icon': h.icon,
      'color': h.color,
      'examCategory': h.examCategory.name,
      'customCategory': h.customCategory,
      'frequencyType': h.frequencyType.name,
      'weeklyCount': h.weeklyCount,
      'customDays': h.customDays,
      'createdAt': h.createdAt.toIso8601String(),
      'isActive': h.isActive,
    }).toList();
  }

  /// 从 JSON 导入习惯（从服务器下载后合并到本地）
  Future<void> importFromJson(List<dynamic> jsonList) async {
    if (jsonList.isEmpty) return;

    final box = StorageService.habitBox;
    int importedCount = 0;

    for (final item in jsonList) {
      try {
        final id = item['id'] as String;
        // 跳过已存在的习惯（ID 相同视为已存在）
        if (_habits.any((h) => h.id == id)) continue;

        final habit = Habit(
          id: id,
          name: item['name'] as String,
          icon: item['icon'] as String,
          color: item['color'] as int,
          examCategory: ExamCategory.values.firstWhere(
            (e) => e.name == item['examCategory'],
            orElse: () => ExamCategory.custom,
          ),
          customCategory: item['customCategory'] as String?,
          frequencyType: FrequencyType.values.firstWhere(
            (f) => f.name == item['frequencyType'],
            orElse: () => FrequencyType.daily,
          ),
          weeklyCount: item['weeklyCount'] as int? ?? 7,
          customDays: (item['customDays'] as List?)?.cast<int>() ?? [1,2,3,4,5,6,7],
          createdAt: DateTime.parse(item['createdAt'] as String),
          isActive: item['isActive'] as bool? ?? true,
        );

        await box.put(habit.id, habit);
        _habits.add(habit);
        importedCount++;
      } catch (e) {
        debugPrint('导入习惯失败: $e');
      }
    }

    if (importedCount > 0) {
      _invalidateCache();
      notifyListeners();
      WidgetService.updateWidgetData(_habits);
      onDataChanged?.call();
      debugPrint('从云端导入 $importedCount 个习惯');
    }
  }
}