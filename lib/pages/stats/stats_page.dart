import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/focus_provider.dart';
import '../../utils/timer_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pie_chart_widget.dart';
import '../../widgets/line_chart_widget.dart';

/// 统计页：数据统计与可视化
///
/// 反焦虑设计原则：
/// 1. 核心数据优先展示：本周学习时长、本周完成率
/// 2. 累计数据次之：累计打卡次数、累计学习时长
/// 3. 连续天数弱化展示：字号更小、颜色更浅
/// 4. 日历热力图：柔和配色，无打卡为浅灰色
/// 5. 科目占比饼图：清晰直观
/// 6. 周/月趋势：折线图展示变化
/// 7. 每周学习报告：正向鼓励，不批评
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  /// 记录上次专注状态，用于检测专注会话结束
  TimerState _lastTimerState = TimerState.idle;

  @override
  void initState() {
    super.initState();
    // 页面加载时加载统计数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 只监听 timerState 的变化，避免每秒计时器 tick 触发整页重建
    // （原来 context.watch<FocusProvider>() 会因 remainingSeconds 等字段变化而每秒重建）
    final timerState =
        context.select<FocusProvider, TimerState>((p) => p.timerState);

    // 检测专注会话结束（从非 idle 状态回到 idle 状态），刷新统计数据
    if (_lastTimerState != TimerState.idle && timerState == TimerState.idle) {
      // 使用 postFrameCallback 避免在 build 中触发 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // mounted 检查：防止 widget 在回调触发前已被卸载（如页面切换）时抛异常
        if (!mounted) return;
        context.read<StatsProvider>().refresh();
      });
    }
    _lastTimerState = timerState;

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: const Text('统计'),
        actions: [
          // 周/月切换按钮
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              _showViewToggleDialog(context);
            },
            tooltip: '切换周/月视图',
          ),
        ],
      ),
      body: Consumer<StatsProvider>(
        builder: (context, statsProvider, _) {
          if (statsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ===== 第一优先级：本周数据 =====
                  _buildPrimaryStats(theme, statsProvider),
                  const SizedBox(height: 16),

                  // ===== 第二优先级：累计数据 =====
                  _buildSecondaryStats(theme, statsProvider),
                  const SizedBox(height: 24),

                  // ===== 弱化展示：连续打卡天数 =====
                  _buildStreakIndicator(theme, statsProvider),
                  const SizedBox(height: 24),

                  const SizedBox(height: 8),

                  // ===== 科目占比饼图 =====
                  PieChartWidget(
                    data: statsProvider.subjectStudyMinutes,
                    title: '科目学习时长占比',
                  ),
                  const SizedBox(height: 24),

                  // ===== 学习时长趋势 =====
                  _buildTrendChart(theme, statsProvider),
                  const SizedBox(height: 24),

                  // ===== 每周学习报告 =====
                  if (statsProvider.lastWeekReport != null)
                    _buildWeeklyReport(theme, statsProvider),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建第一优先级统计卡片（本周数据）
  Widget _buildPrimaryStats(ThemeData theme, StatsProvider statsProvider) {
    return Column(
      children: [
        // 本周学习总时长
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本周学习时长',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statsProvider.formatDurationFromSeconds(statsProvider.weeklyStudySeconds),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本周的努力都在这里',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 本周完成率
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.secondaryLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本周完成率',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statsProvider.formatCompletionRate(
                            statsProvider.weeklyCompletionRate),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '休息日不计入',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建第二优先级统计卡片（累计数据）
  Widget _buildSecondaryStats(ThemeData theme, StatsProvider statsProvider) {
    return Row(
      children: [
        // 累计打卡总次数
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '累计打卡次数',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${statsProvider.totalCheckInCount}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 累计学习总时长
        Flexible(
          fit: FlexFit.loose,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '累计学习时长',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    statsProvider.formatDurationFromSeconds(statsProvider.totalStudySeconds),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建连续打卡天数弱化展示
  Widget _buildStreakIndicator(ThemeData theme, StatsProvider statsProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 16,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Text(
            '当前连续打卡 ${statsProvider.currentStreak} 天',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建趋势图表（周/月切换）
  ///
  /// 月视图时在标题下方提供月份切换 UI，避免 [StatsProvider.previousMonth] /
  /// [nextMonth] / [setSelectedMonth] 成为死代码。
  Widget _buildTrendChart(ThemeData theme, StatsProvider statsProvider) {
    final isWeekView = statsProvider.viewType == ViewType.week;
    final title = isWeekView ? '本周学习时长趋势' : '本月学习时长趋势';
    final data = isWeekView
        ? statsProvider.weeklyDailyMinutes
        : statsProvider.monthlyDailyMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 月视图：月份导航条
        if (!isWeekView) _buildMonthNavigator(theme, statsProvider),
        if (!isWeekView) const SizedBox(height: 8),
        LineChartWidget(
          data: data,
          title: title,
          isWeekView: isWeekView,
        ),
      ],
    );
  }

  /// 月视图月份导航条
  ///
  /// - 上个月 / 下个月按钮，中间显示当前选中月份
  /// - 下个月按钮在选中月 >= 当前月时禁用，避免查看无意义的未来月份
  Widget _buildMonthNavigator(ThemeData theme, StatsProvider statsProvider) {
    final selected = statsProvider.selectedMonth;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final canGoNext = selected.isBefore(currentMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上个月
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: '上个月',
            onPressed: () => statsProvider.previousMonth(),
          ),
          // 当前选中月份
          Text(
            '${selected.year} 年 ${selected.month} 月',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          // 下个月（不能超过当前月）
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: canGoNext ? '下个月' : '已是最新月份',
            onPressed: canGoNext ? () => statsProvider.nextMonth() : null,
          ),
        ],
      ),
    );
  }

  /// 构建每周学习报告
  Widget _buildWeeklyReport(ThemeData theme, StatsProvider statsProvider) {
    final report = statsProvider.lastWeekReport!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '上周学习报告',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 报告数据概览
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学习时长',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.formattedTotalDuration,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '专注次数',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${report.totalSessions}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '完成率',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(report.completionRate * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 正向鼓励文案
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Text(
              report.encouragement,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示视图切换对话框
  void _showViewToggleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择视图'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('周视图'),
                leading: const Icon(Icons.calendar_view_week),
                selected: context.read<StatsProvider>().viewType == ViewType.week,
                onTap: () {
                  context.read<StatsProvider>().setViewType(ViewType.week);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('月视图'),
                leading: const Icon(Icons.calendar_view_month),
                selected:
                    context.read<StatsProvider>().viewType == ViewType.month,
                onTap: () {
                  context.read<StatsProvider>().setViewType(ViewType.month);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

}