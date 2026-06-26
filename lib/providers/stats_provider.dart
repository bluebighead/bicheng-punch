import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/check_in_model.dart';
import '../models/focus_record_model.dart';
import '../models/habit_model.dart';
import '../services/storage_service.dart';
import '../utils/stats_utils.dart';

/// 统计数据状态管理 Provider
///
/// 职责：
/// 1. 从各个 Provider 汇总数据
/// 2. 计算各类统计指标
/// 3. 管理周报生成
/// 4. 提供统计数据访问接口
/// 5. 生成测试数据以验证图表渲染
class StatsProvider extends ChangeNotifier {
  List<FocusRecord> _focusRecords = [];
  List<CheckIn> _checkIns = [];
  List<Habit> _habits = [];
  List<DateTime> _restDays = [];
  bool _isLoading = false;

  /// 是否已加载测试数据
  bool _hasTestData = false;

  /// 周报缓存
  WeeklyReport? _lastWeekReport;

  /// 当前选择的视图类型（周/月）
  ViewType _viewType = ViewType.week;

  /// 当前选择的月份（用于月视图）
  DateTime _selectedMonth = DateTime.now();

  // ===== Getters =====
  List<FocusRecord> get focusRecords => _focusRecords;
  List<CheckIn> get checkIns => _checkIns;
  List<Habit> get habits => _habits;
  List<DateTime> get restDays => _restDays;
  bool get isLoading => _isLoading;
  bool get hasTestData => _hasTestData;
  WeeklyReport? get lastWeekReport => _lastWeekReport;
  ViewType get viewType => _viewType;
  DateTime get selectedMonth => _selectedMonth;

  /// 本周学习总时长（分钟）
  int get weeklyStudyMinutes =>
      StatsUtils.getWeeklyStudyMinutes(_focusRecords);

  /// 累计学习总时长（分钟）
  int get totalStudyMinutes =>
      StatsUtils.getTotalStudyMinutes(_focusRecords);

  /// 本周完成率
  double get weeklyCompletionRate =>
      StatsUtils.getWeeklyCompletionRate(_checkIns, _habits, _restDays);

  /// 累计打卡总次数
  int get totalCheckInCount =>
      StatsUtils.getTotalCheckInCount(_checkIns);

  /// 当前连续打卡天数
  int get currentStreak =>
      StatsUtils.getCurrentStreak(_checkIns, _habits, _restDays);

  /// 本周每日学习时长
  Map<DateTime, int> get weeklyDailyMinutes =>
      StatsUtils.getWeeklyDailyMinutes(_focusRecords);

  /// 本月每日学习时长
  Map<DateTime, int> get monthlyDailyMinutes =>
      StatsUtils.getMonthlyDailyMinutes(
          _focusRecords, _selectedMonth.year, _selectedMonth.month);

  /// 各科目学习时长占比
  Map<String, int> get subjectStudyMinutes =>
      StatsUtils.getSubjectStudyMinutes(_focusRecords, _habits);

  /// 各习惯学习时长占比
  Map<String, int> get habitStudyMinutes =>
      StatsUtils.getHabitStudyMinutes(_focusRecords, _habits);

  /// 本月打卡热力图数据
  Map<DateTime, int> get monthlyCheckInHeatmap =>
      StatsUtils.getMonthlyCheckInHeatmap(
          _checkIns, _selectedMonth.year, _selectedMonth.month);

  /// 初始化：加载所有数据
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 从 Hive 加载数据
      _focusRecords = StorageService.focusRecordBox.values.toList();
      _checkIns = StorageService.checkInBox.values.toList();
      _habits = StorageService.habitBox.values.toList();

      // 加载休息日配置
      _loadRestDays();

      // 检查是否有测试数据标记
      _hasTestData = StorageService.configBox.get('test_data_enabled', defaultValue: false) as bool;

      // 如果有测试数据标记但数据为空，重新生成内存数据
      if (_hasTestData && _focusRecords.isEmpty) {
        _generateTestDataInMemory();
      }

      // 检查是否需要生成上周周报（每周一）
      _checkAndGenerateWeeklyReport();

      debugPrint(
          '统计 Provider 加载完成：${_focusRecords.length} 条专注记录，${_checkIns.length} 条打卡记录');
    } catch (e) {
      debugPrint('加载统计数据失败: $e');
      _focusRecords = [];
      _checkIns = [];
      _habits = [];
      _restDays = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载休息日配置
  void _loadRestDays() {
    // 从配置中加载休息日
    final configBox = StorageService.configBox;
    final restDaysKeys = configBox.keys.where((key) =>
        key.toString().startsWith('rest_day_'));

    _restDays = restDaysKeys.map((key) {
      final keyStr = key.toString();
      // 解析日期：rest_day_2024_1_15
      final parts = keyStr.split('_');
      if (parts.length >= 4) {
        try {
          final year = int.parse(parts[2]);
          final month = int.parse(parts[3]);
          final day = int.parse(parts[4]);
          return DateTime(year, month, day);
        } catch (e) {
          return null;
        }
      }
      return null;
    }).whereType<DateTime>().toList();
  }

  /// 检查并生成周报（每周一自动生成）
  void _checkAndGenerateWeeklyReport() {
    final now = DateTime.now();
    final lastReportKey = 'last_weekly_report_${now.year}_${now.month}';

    // 检查本周是否已生成周报
    final lastReportTime = StorageService.configBox.get(lastReportKey);
    if (lastReportTime != null) {
      // 加载上周周报
      _lastWeekReport = StatsUtils.generateWeeklyReport(
          _focusRecords, _checkIns, _habits, _restDays);
    }

    // 如果今天是周一，生成上周周报
    if (now.weekday == DateTime.monday) {
      final todayKey = 'weekly_report_generated_${now.year}_${now.month}_${now.day}';
      final generatedToday = StorageService.configBox.get(todayKey);

      if (generatedToday == null) {
        // 今天还没生成周报
        _lastWeekReport = StatsUtils.generateWeeklyReport(
            _focusRecords, _checkIns, _habits, _restDays);

        // 标记今天已生成
        StorageService.configBox.put(todayKey, true);
        StorageService.configBox.put(lastReportKey, now.millisecondsSinceEpoch);

        debugPrint('已生成上周学习报告');
      }
    }
  }

  /// 切换视图类型（周/月）
  void setViewType(ViewType type) {
    _viewType = type;
    // 切换视图时重新加载数据，确保数据完整性
    if (_focusRecords.isEmpty) {
      refresh();
    } else {
      notifyListeners();
    }
  }

  /// 设置选择的月份
  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    notifyListeners();
  }

  /// 切换到上个月
  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    notifyListeners();
  }

  /// 切换到下个月
  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    notifyListeners();
  }

  /// 手动生成周报
  void generateWeeklyReport() {
    _lastWeekReport = StatsUtils.generateWeeklyReport(
        _focusRecords, _checkIns, _habits, _restDays);
    notifyListeners();
  }

  /// 刷新统计数据（从 Hive 重新加载）
  Future<void> refresh() async {
    try {
      // 如果测试数据已启用，不要从 Hive 覆盖内存中的测试数据
      if (!_hasTestData) {
        _focusRecords = StorageService.focusRecordBox.values.toList();
      }
      _checkIns = StorageService.checkInBox.values.toList();
      _habits = StorageService.habitBox.values.toList();
      _loadRestDays();
      _checkAndGenerateWeeklyReport();
    } catch (e) {
      debugPrint('刷新统计数据失败: $e');
    }
    notifyListeners();
  }

  /// ===== 测试数据管理 =====

  /// 开启/关闭测试数据
  Future<void> setTestDataEnabled(bool enabled) async {
    await StorageService.configBox.put('test_data_enabled', enabled);
    _hasTestData = enabled;

    if (enabled) {
      // 生成内存测试数据（不写 Hive，不破坏真实数据）
      _generateTestDataInMemory();
    } else {
      // 关闭测试数据：只清空内存数据，不清空 Hive（保护用户真实数据）
      _focusRecords = [];
      // 从 Hive 重新加载真实数据
      _focusRecords = StorageService.focusRecordBox.values.toList();
      _checkIns = StorageService.checkInBox.values.toList();
      _habits = StorageService.habitBox.values.toList();
      _loadRestDays();
    }

    debugPrint('测试数据模式: ${enabled ? "开启" : "关闭"}，当前 ${_focusRecords.length} 条记录');
    notifyListeners();
  }

  /// 直接生成内存测试数据（不写 Hive，立即生效）
  void _generateTestDataInMemory() {
    final now = DateTime.now();
    final uuid = Uuid();
    final records = <FocusRecord>[];

    // 创建虚拟习惯，用于饼图分类展示
    const testHabitIds = ['test_habit_1', 'test_habit_2', 'test_habit_3'];
    const testHabitNames = ['数学', '英语', '专业课'];
    const testHabitCategories = [
      ExamCategory.kaoyan,
      ExamCategory.cet4cet6,
      ExamCategory.custom,
    ];
    _habits = List.generate(3, (i) => Habit(
      id: testHabitIds[i],
      name: testHabitNames[i],
      icon: 'book',
      color: 0xFF6B8E9F,
      isActive: true,
      examCategory: testHabitCategories[i],
      frequencyType: FrequencyType.daily,
      createdAt: now,
    ));

    // 获取本周起始（周一）
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // 生成本周每天的数据（前6天），随机分配到3个习惯
    for (int i = 0; i < 6; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(now)) break;

      // 每天 1-3 次专注，时长 15-90 分钟
      final sessions = 1 + (i * 7) % 3;
      int dailyMinutes = 0;

      for (int s = 0; s < sessions; s++) {
        final minutes = 15 + ((i * 13 + s * 11) % 75);
        dailyMinutes += minutes;
        final start = DateTime(
          date.year, date.month, date.day,
          8 + (s * 3) % 12,
          (s * 23) % 60,
        );
        final end = start.add(Duration(minutes: minutes));

        records.add(FocusRecord(
          id: uuid.v4(),
          mode: FocusMode.countdown,
          duration: minutes * 60,
          targetDuration: minutes * 60,
          // 轮替分配 habitId，使饼图有多段数据
          habitId: testHabitIds[(i + s) % 3],
          startTime: start,
          endTime: end,
          createdAt: start,
        ));
      }

      debugPrint('测试数据：$date 日专注 $dailyMinutes 分钟');
    }

    // 生成上个月末一周的数据（用于月视图）
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    for (int d = lastMonthEnd.day - 6; d <= lastMonthEnd.day; d++) {
      if (d < 1) continue;
      final date = DateTime(now.year, now.month - 1, d);
      final minutes = 20 + (d * 7) % 60;
      final start = DateTime(date.year, date.month, date.day, 10, 0);
      final end = start.add(Duration(minutes: minutes));

      records.add(FocusRecord(
        id: uuid.v4(),
        mode: FocusMode.countdown,
        duration: minutes * 60,
        targetDuration: minutes * 60,
        habitId: testHabitIds[d % 3],
        startTime: start,
        endTime: end,
        createdAt: start,
      ));
    }

    _focusRecords = records;
    debugPrint('测试数据生成完成：共 ${records.length} 条专注记录');

    // 验证饼图数据
    final pieData = StatsUtils.getSubjectStudyMinutes(_focusRecords, _habits);
    debugPrint('饼图数据: ${pieData.length} 项');
    for (final entry in pieData.entries) {
      debugPrint('  ${entry.key}: ${entry.value}分钟');
    }

    // 验证本周数据
    final weeklyData = StatsUtils.getWeeklyDailyMinutes(_focusRecords);
    debugPrint('本周数据点数: ${weeklyData.length}');
    for (final entry in weeklyData.entries) {
      debugPrint('  ${entry.key}: ${entry.value}分钟');
    }
  }

  /// 格式化时长（分钟转小时分钟）
  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0) {
      return '$hours 小时 $mins 分钟';
    } else {
      return '$mins 分钟';
    }
  }

  /// 格式化完成率（百分比）
  String formatCompletionRate(double rate) {
    return '${(rate * 100).toStringAsFixed(0)}%';
  }
}

/// 视图类型枚举
enum ViewType {
  week, // 周视图
  month, // 月视图
}
