import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../providers/habit_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../providers/login_provider.dart';
import '../../routes/app_routes.dart';

/// 月历视图组件
///
/// 设计原则：
/// - 已打卡日期标记柔和圆点，无红色刺眼标记
/// - 未打卡无任何标记（不制造焦虑）
/// - 休息日标记特殊图标（月亮/星星）
/// - 点击历史日期可补签（需有补签额度）
class MonthCalendarWidget extends StatefulWidget {
  const MonthCalendarWidget({super.key});

  @override
  State<MonthCalendarWidget> createState() => _MonthCalendarWidgetState();
}

class _MonthCalendarWidgetState extends State<MonthCalendarWidget> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitProvider = context.watch<HabitProvider>();
    final checkInProvider = context.watch<CheckInProvider>();

    // 获取当月所有打卡记录
    final monthCheckIns = checkInProvider.checkIns.where((c) =>
        c.date.year == _currentMonth.year &&
        c.date.month == _currentMonth.month).toList();

    // 计算当月打卡天数（去重）
    final checkedDates = monthCheckIns.map((c) => c.date.day).toSet();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.pagePaddingH),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // 月份导航
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _prevMonth(),
                tooltip: '上个月',
              ),
              Text(
                '${_currentMonth.year}年${_currentMonth.month}月',
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _nextMonth(),
                tooltip: '下个月',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 补签额度提示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_fix_high, size: 16, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                '本月补签额度：${checkInProvider.getRemainingMakeupQuota()} 次',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 周标题行
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 8),

          // 日期网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _getDaysInMonth(),
            itemBuilder: (context, index) {
              final day = index + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = _isToday(date);
              final isChecked = checkedDates.contains(day);
              final isRestDay = checkInProvider.isRestDay(date);
              final isFuture = date.isAfter(DateTime.now());

              return _buildDayCell(
                context,
                date,
                isToday,
                isChecked,
                isRestDay,
                isFuture,
                habitProvider,
                checkInProvider,
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建单个日期单元格
  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    bool isToday,
    bool isChecked,
    bool isRestDay,
    bool isFuture,
    HabitProvider habitProvider,
    CheckInProvider checkInProvider,
  ) {
    final theme = Theme.of(context);

    // 背景/边框样式
    BoxDecoration? decoration;
    if (isToday) {
      decoration = BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      );
    } else if (isChecked) {
      decoration = BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      );
    }

    // 点击事件（历史日期可补签，需登录）
    VoidCallback? onTap;
    if (!isFuture && !isChecked && !isRestDay) {
      onTap = () {
        // 检查登录状态
        final loginProvider = context.read<LoginProvider>();
        if (!loginProvider.isLoggedIn) {
          _showLoginRequiredDialog();
          return;
        }
        _showMakeupDialog(date, habitProvider, checkInProvider);
      };
    } else if (isRestDay) {
      onTap = () => _showRestDayDialog(date, checkInProvider);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 日期数字
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isFuture
                    ? AppColors.textHint
                    : isChecked
                        ? AppColors.primary
                        : AppColors.textPrimary,
              ),
            ),

            // 状态标记（圆点/图标）
            if (isChecked && !isRestDay)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),

            if (isRestDay)
              Positioned(
                bottom: 2,
                child: Icon(
                  Icons.bedtime,
                  size: 12,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 获取当月天数
  int _getDaysInMonth() {
    return DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
  }

  /// 判断是否为今日
  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  /// 上个月
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  /// 下个月
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  /// 显示补签弹窗
  void _showMakeupDialog(
    DateTime date,
    HabitProvider habitProvider,
    CheckInProvider checkInProvider,
  ) {
    final todayHabits = habitProvider.getTodayHabits();

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.month}月${date.day}日补签',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '剩余额度：${checkInProvider.getRemainingMakeupQuota()} 次',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (checkInProvider.getRemainingMakeupQuota() <= 0)
              Center(
                child: Text(
                  '本月补签额度已用完，下月自动发放',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else if (todayHabits.isEmpty)
              Center(
                child: Text(
                  '还没有习惯',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                itemCount: todayHabits.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final habit = todayHabits[index];
                  final alreadyChecked =
                      checkInProvider.isCheckedIn(habit.id, date);

                  return ListTile(
                    leading: Icon(Icons.history, color: AppColors.primary),
                    title: Text(habit.name),
                    subtitle: Text(alreadyChecked ? '已补签' : '点击补签'),
                    trailing: alreadyChecked
                        ? const Icon(Icons.check, color: AppColors.secondary)
                        : null,
                    onTap: alreadyChecked
                        ? null
                        : () {
                            checkInProvider.checkIn(
                              habit.id,
                              date,
                              null,
                              null,
                              null,
                            );
                            Navigator.pop(context);
                          },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 显示休息日设置弹窗
  void _showRestDayDialog(DateTime date, CheckInProvider checkInProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('休息日'),
        content: Text('${date.month}月${date.day}日已标记为休息日，对应习惯自动标记为完成。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          TextButton(
            onPressed: () {
              checkInProvider.markRestDay(date, false);
              Navigator.pop(context);
            },
            child: const Text('取消休息日'),
          ),
        ],
      ),
    );
  }

  /// 显示登录引导弹窗：补签需要先登录
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('补签功能需要登录后才能使用，请先登录账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 跳转到登录页面
              Navigator.pushNamed(context, AppRoutes.login);
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }
}