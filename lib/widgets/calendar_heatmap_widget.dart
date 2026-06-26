import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 日历热力图组件
///
/// 反焦虑设计原则：
/// - 月视图展示打卡情况
/// - 颜色深浅对应学习时长，柔和配色
/// - 无打卡为浅灰色，不用红色标记未打卡
class CalendarHeatmapWidget extends StatelessWidget {
  const CalendarHeatmapWidget({
    super.key,
    required this.year,
    required this.month,
    required this.heatmapData,
    this.onDayTap,
  });

  final int year;
  final int month;
  final Map<DateTime, int> heatmapData; // 日期 -> 打卡次数
  final Function(DateTime)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 获取该月的第一天和总天数
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // 获取该月第一天是星期几（1=周一，7=周日）
    final firstWeekday = firstDay.weekday;

    // 计算该月第一周需要填充的空白天数
    final leadingEmptyDays = firstWeekday - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 月份标题
          Text(
            '$year年$month月',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // 星期标题
          _buildWeekdayHeaders(theme),
          const SizedBox(height: 8),

          // 日历网格
          _buildCalendarGrid(theme, daysInMonth, leadingEmptyDays),
        ],
      ),
    );
  }

  /// 构建星期标题
  Widget _buildWeekdayHeaders(ThemeData theme) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建日历网格
  Widget _buildCalendarGrid(
    ThemeData theme,
    int daysInMonth,
    int leadingEmptyDays,
  ) {
    final rows = <Widget>[];
    final cells = <Widget>[];

    // 添加前面的空白单元格
    for (int i = 0; i < leadingEmptyDays; i++) {
      cells.add(const Expanded(child: SizedBox()));
    }

    // 添加日期单元格
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final checkInCount = heatmapData[date] ?? 0;

      cells.add(
        Expanded(
          child: _buildDayCell(
            theme,
            day,
            checkInCount,
            date,
          ),
        ),
      );

      // 每7个单元格一行
      if (cells.length == 7) {
        rows.add(Row(children: cells));
        rows.add(const SizedBox(height: 4));
        cells.clear();
      }
    }

    // 添加末尾的空白单元格，补齐最后一行
    if (cells.isNotEmpty && cells.length < 7) {
      while (cells.length < 7) {
        cells.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: cells));
    }

    return Column(children: rows);
  }

  /// 构建单个日期单元格
  Widget _buildDayCell(
    ThemeData theme,
    int day,
    int checkInCount,
    DateTime date,
  ) {
    // 获取热力图颜色
    final color = _getHeatmapColor(checkInCount);

    // 判断是否为今天
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    return GestureDetector(
      onTap: onDayTap != null ? () => onDayTap!(date) : null,
      child: Container(
        height: 32,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: isToday
              ? Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: checkInCount > 0 ? Colors.white : AppColors.textSecondary,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 根据打卡次数获取热力图颜色
  ///
  /// 反焦虑设计：柔和配色，无打卡为浅灰色，不用红色
  Color _getHeatmapColor(int checkInCount) {
    if (checkInCount == 0) {
      return AppColors.lightCard; // 无打卡：浅灰色
    } else if (checkInCount == 1) {
      return AppColors.secondaryLight.withValues(alpha: 0.6); // 1次：浅绿色
    } else if (checkInCount == 2) {
      return AppColors.secondaryLight.withValues(alpha: 0.8); // 2次：中绿色
    } else if (checkInCount == 3) {
      return AppColors.secondary; // 3次：柔和绿色
    } else if (checkInCount == 4) {
      return AppColors.primaryLight; // 4次：浅蓝色
    } else {
      return AppColors.primary; // 5次及以上：莫兰迪蓝
    }
  }
}