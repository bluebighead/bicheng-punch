import '../models/check_in_model.dart';
import '../models/focus_record_model.dart';
import '../models/habit_model.dart';

/// 统计工具类
///
/// 提供各类统计数据计算方法，遵循反焦虑设计原则：
/// - 优先展示本周数据，淡化累计数据
/// - 休息日不计入完成率分母
/// - 连续天数弱化展示，不强调不批评
class StatsUtils {
  StatsUtils._();

  /// 计算本周学习总时长（分钟）
  ///
  /// 本周定义：周一到周日
  static int getWeeklyStudyMinutes(List<FocusRecord> records) {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    return records
        .where((r) =>
            r.startTime.isAfter(weekStart) && r.startTime.isBefore(weekEnd))
        .fold(0, (sum, r) => sum + r.duration ~/ 60);
  }

  /// 计算累计学习总时长（分钟）
  static int getTotalStudyMinutes(List<FocusRecord> records) {
    return records.fold(0, (sum, r) => sum + r.duration ~/ 60);
  }

  /// 计算本周完成率
  ///
  /// 完成率 = 实际打卡次数 / 应打卡次数（休息日不计入）
  static double getWeeklyCompletionRate(
    List<CheckIn> checkIns,
    List<Habit> habits,
    List<DateTime> restDays,
  ) {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    int totalRequired = 0;
    int actualCompleted = 0;

    // 遍历本周每一天
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(now)) break; // 超过今天的不计入

      // 检查是否为休息日
      final isRestDay = restDays.any((r) =>
          r.year == date.year && r.month == date.month && r.day == date.day);
      if (isRestDay) continue; // 休息日不计入分母

      // 统计当日应打卡的习惯数量
      for (final habit in habits) {
        if (!habit.isActive) continue;
        if (habit.shouldCheckInOn(date)) {
          totalRequired++;

          // 检查是否已打卡
          final hasCheckedIn = checkIns.any((c) =>
              c.habitId == habit.id &&
              c.date.year == date.year &&
              c.date.month == date.month &&
              c.date.day == date.day);

          if (hasCheckedIn) {
            actualCompleted++;
          }
        }
      }
    }

    if (totalRequired == 0) return 0.0;
    return actualCompleted / totalRequired;
  }

  /// 计算累计打卡总次数
  static int getTotalCheckInCount(List<CheckIn> checkIns) {
    return checkIns.length;
  }

  /// 计算当前连续打卡天数
  ///
  /// 从今天往前推，连续有打卡的天数
  /// 注意：连续天数只展示，不强调不批评
  static int getCurrentStreak(
    List<CheckIn> checkIns,
    List<Habit> habits,
    List<DateTime> restDays,
  ) {
    final now = DateTime.now();
    int streak = 0;

    // 从今天往前推
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));

      // 检查是否为休息日
      final isRestDay = restDays.any((r) =>
          r.year == date.year && r.month == date.month && r.day == date.day);

      if (isRestDay) {
        // 休息日不中断，继续往前推
        continue;
      }

      // 检查当日是否有至少一个习惯打卡
      bool hasAnyCheckIn = false;
      for (final habit in habits) {
        if (!habit.isActive) continue;
        if (!habit.shouldCheckInOn(date)) continue;

        final hasCheckedIn = checkIns.any((c) =>
            c.habitId == habit.id &&
            c.date.year == date.year &&
            c.date.month == date.month &&
            c.date.day == date.day);

        if (hasCheckedIn) {
          hasAnyCheckIn = true;
          break;
        }
      }

      if (hasAnyCheckIn) {
        streak++;
      } else if (i > 0) {
        // 如果今天还没打卡不算中断，否则停止
        break;
      }
    }

    return streak;
  }

  /// 获取某月每日学习时长（用于折线图）
  ///
  /// 返回 Map<日期, 时长分钟>
  static Map<DateTime, int> getMonthlyDailyMinutes(
    List<FocusRecord> records,
    int year,
    int month,
  ) {
    final result = <DateTime, int>{};

    for (final record in records) {
      if (record.startTime.year == year && record.startTime.month == month) {
        final date = DateTime(record.startTime.year, record.startTime.month,
            record.startTime.day);
        final minutes = record.duration ~/ 60;

        if (result.containsKey(date)) {
          result[date] = result[date]! + minutes;
        } else {
          result[date] = minutes;
        }
      }
    }

    return result;
  }

  /// 获取某周每日学习时长（用于折线图）
  ///
  /// 返回 Map<日期, 时长分钟>
  /// 只有当日有实际学习时长（>0分钟）时才加入结果，确保空数据时显示"暂无数据"
  static Map<DateTime, int> getWeeklyDailyMinutes(List<FocusRecord> records) {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final result = <DateTime, int>{};

    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      if (date.isAfter(now)) break;

      final dayRecords = records.where((r) =>
          r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day);

      final totalMinutes = dayRecords.fold(0, (sum, r) => sum + r.duration ~/ 60);
      // 只有当日有实际学习时长时才加入结果，避免空数据时显示空白图表
      if (totalMinutes > 0) {
        result[DateTime(date.year, date.month, date.day)] = totalMinutes;
      }
    }

    return result;
  }

  /// 获取各科目学习时长占比（用于饼图）
  ///
  /// 返回 Map<科目名称, 时长分钟>
  static Map<String, int> getSubjectStudyMinutes(
    List<FocusRecord> records,
    List<Habit> habits,
  ) {
    final result = <String, int>{};

    for (final record in records) {
      if (record.habitId == null) continue;

      // 查找对应的习惯
      final habit = habits.firstWhere(
        (h) => h.id == record.habitId,
        orElse: () => habits.first, // 容错
      );

      final subjectName = _getCategoryName(habit.examCategory);
      final minutes = record.duration ~/ 60;

      if (result.containsKey(subjectName)) {
        result[subjectName] = result[subjectName]! + minutes;
      } else {
        result[subjectName] = minutes;
      }
    }

    return result;
  }

  /// 获取各习惯学习时长占比（用于饼图）
  ///
  /// 返回 Map<习惯名称, 时长分钟>
  static Map<String, int> getHabitStudyMinutes(
    List<FocusRecord> records,
    List<Habit> habits,
  ) {
    final result = <String, int>{};

    for (final record in records) {
      if (record.habitId == null) continue;

      final habit = habits.firstWhere(
        (h) => h.id == record.habitId,
        orElse: () => habits.first,
      );

      final minutes = record.duration ~/ 60;

      if (result.containsKey(habit.name)) {
        result[habit.name] = result[habit.name]! + minutes;
      } else {
        result[habit.name] = minutes;
      }
    }

    return result;
  }

  /// 获取某月每日打卡情况（用于日历热力图）
  ///
  /// 返回 Map<日期, 打卡次数>
  static Map<DateTime, int> getMonthlyCheckInHeatmap(
    List<CheckIn> checkIns,
    int year,
    int month,
  ) {
    final result = <DateTime, int>{};

    for (final checkIn in checkIns) {
      if (checkIn.date.year == year && checkIn.date.month == month) {
        final date =
            DateTime(checkIn.date.year, checkIn.date.month, checkIn.date.day);

        if (result.containsKey(date)) {
          result[date] = result[date]! + 1;
        } else {
          result[date] = 1;
        }
      }
    }

    return result;
  }

  /// 生成上周学习报告
  ///
  /// 遵循反焦虑原则：只展示数据和正向鼓励，不做批评式对比
  static WeeklyReport generateWeeklyReport(
    List<FocusRecord> records,
    List<CheckIn> checkIns,
    List<Habit> habits,
    List<DateTime> restDays,
  ) {
    final now = DateTime.now();
    final lastWeekStart = _getWeekStart(now).subtract(const Duration(days: 7));
    final lastWeekEnd = lastWeekStart.add(const Duration(days: 7));

    // 筛选上周的专注记录
    final lastWeekRecords = records.where((r) =>
        r.startTime.isAfter(lastWeekStart) &&
        r.startTime.isBefore(lastWeekEnd));

    // 筛选上周的打卡记录
    final lastWeekCheckIns = checkIns.where((c) =>
        c.date.isAfter(lastWeekStart) && c.date.isBefore(lastWeekEnd));

    // 统计数据
    final totalMinutes = lastWeekRecords.fold(0, (sum, r) => sum + r.duration ~/ 60);
    final totalSessions = lastWeekRecords.length;
    final totalCheckIns = lastWeekCheckIns.length;

    // 计算上周完成率
    int totalRequired = 0;
    int actualCompleted = 0;

    for (int i = 0; i < 7; i++) {
      final date = lastWeekStart.add(Duration(days: i));

      // 检查是否为休息日
      final isRestDay = restDays.any((r) =>
          r.year == date.year && r.month == date.month && r.day == date.day);
      if (isRestDay) continue;

      for (final habit in habits) {
        if (!habit.shouldCheckInOn(date)) continue;

        totalRequired++;
        final hasCheckedIn = lastWeekCheckIns.any((c) =>
            c.habitId == habit.id &&
            c.date.year == date.year &&
            c.date.month == date.month &&
            c.date.day == date.day);

        if (hasCheckedIn) actualCompleted++;
      }
    }

    final completionRate =
        totalRequired > 0 ? actualCompleted / totalRequired : 0.0;

    // 统计每日学习时长
    final dailyMinutes = <DateTime, int>{};
    for (final record in lastWeekRecords) {
      final date =
          DateTime(record.startTime.year, record.startTime.month, record.startTime.day);
      final minutes = record.duration ~/ 60;

      if (dailyMinutes.containsKey(date)) {
        dailyMinutes[date] = dailyMinutes[date]! + minutes;
      } else {
        dailyMinutes[date] = minutes;
      }
    }

    // 生成正向鼓励文案
    final encouragement = _generateEncouragement(
      totalMinutes: totalMinutes,
      totalSessions: totalSessions,
      completionRate: completionRate,
    );

    return WeeklyReport(
      weekStart: lastWeekStart,
      weekEnd: lastWeekEnd.subtract(const Duration(days: 1)),
      totalMinutes: totalMinutes,
      totalSessions: totalSessions,
      totalCheckIns: totalCheckIns,
      completionRate: completionRate,
      dailyMinutes: dailyMinutes,
      encouragement: encouragement,
    );
  }

  /// 获取本周起始日期（周一）
  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1=周一，7=周日
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  /// 获取科目名称
  static String _getCategoryName(ExamCategory category) {
    switch (category) {
      case ExamCategory.kaoyan:
        return '考研';
      case ExamCategory.kaogong:
        return '考公';
      case ExamCategory.jiaozhi:
        return '教资';
      case ExamCategory.cet4cet6:
        return '四六级';
      case ExamCategory.custom:
        return '自定义';
    }
  }

  /// 生成正向鼓励文案
  static String _generateEncouragement({
    required int totalMinutes,
    required int totalSessions,
    required double completionRate,
  }) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (totalMinutes == 0) {
      return '上周还未开始学习，这周是新的开始，加油！';
    }

    if (completionRate >= 0.9) {
      return '太棒了！上周投入 $hours 小时 $minutes 分钟，完成率 ${ (completionRate * 100).toStringAsFixed(0)}%，继续保持这个势头！';
    } else if (completionRate >= 0.7) {
      return '做得很好！上周学习 $hours 小时 $minutes 分钟，完成率 ${ (completionRate * 100).toStringAsFixed(0)}%，稳定的进步是最棒的！';
    } else if (completionRate >= 0.5) {
      return '上周学习 $hours 小时 $minutes 分钟，完成率 ${ (completionRate * 100).toStringAsFixed(0)}%，每一份努力都在积累！';
    } else {
      return '上周投入 $hours 小时 $minutes 分钟，每一次专注都是成长，这周继续加油！';
    }
  }
}

/// 周报模型
class WeeklyReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalMinutes; // 总学习时长（分钟）
  final int totalSessions; // 总专注次数
  final int totalCheckIns; // 总打卡次数
  final double completionRate; // 完成率
  final Map<DateTime, int> dailyMinutes; // 每日学习时长
  final String encouragement; // 正向鼓励文案

  WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.totalMinutes,
    required this.totalSessions,
    required this.totalCheckIns,
    required this.completionRate,
    required this.dailyMinutes,
    required this.encouragement,
  });

  /// 获取格式化的时长字符串
  String get formattedTotalDuration {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '$hours 小时 $minutes 分钟';
    } else {
      return '$minutes 分钟';
    }
  }
}