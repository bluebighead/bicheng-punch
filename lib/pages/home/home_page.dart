import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/habit_model.dart';
import '../../models/check_in_model.dart';
import '../../providers/habit_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/month_calendar.dart';

/// 首页：今日打卡概览
///
/// 核心功能：
/// 1. 展示今日所有习惯，卡片式布局
/// 2. 点击卡片一键打卡，打卡后卡片变柔和填充色，搭配轻微震动反馈
/// 3. 右上角日历按钮点击弹出月历视图，查看历史打卡/补签
///
/// 反焦虑设计：
/// - 弱化连续天数，突出累计与完成率
/// - 休息日不计入，放松一下也没关系
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 刷新数据
  void _refreshData() {
    context.read<HabitProvider>().loadHabits();
    context.read<CheckInProvider>().loadCheckIns();
  }

  /// 弹出月历视图（底部弹窗）
  void _showCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CalendarSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitProvider = context.watch<HabitProvider>();
    final checkInProvider = context.watch<CheckInProvider>();

    // 今日需打卡的习惯列表
    final todayHabits = habitProvider.getTodayHabits();

    // 今日已打卡数量
    final todayCheckedCount = todayHabits.where((h) =>
        checkInProvider.isCheckedIn(h.id, DateTime.now())).length;

    // 今日完成率
    final todayCompletionRate = todayHabits.isEmpty
        ? 0.0
        : todayCheckedCount / todayHabits.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: '添加打卡项',
          onPressed: () {
            Navigator.pushNamed(context, '/group');
          },
        ),
        title: const Text('今日打卡'),
        actions: [
          // 日历按钮：点击弹出月历视图
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _showCalendar,
            tooltip: '历史打卡',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 统计概览卡片
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePaddingH),
                child: _buildStatsOverview(
                    theme, todayCheckedCount, todayHabits.length, todayCompletionRate),
              ),

              const SizedBox(height: 16),

              // 今日习惯列表
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('今日待打卡', style: theme.textTheme.titleLarge),
                        if (todayHabits.isNotEmpty)
                          Text(
                            '$todayCheckedCount/${todayHabits.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 习惯卡片列表或空状态
                    if (habitProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (todayHabits.isEmpty)
                      _buildEmptyState(theme)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayHabits.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final habit = todayHabits[index];
                          final isCheckedIn =
                              checkInProvider.isCheckedIn(habit.id, DateTime.now());
                          final checkIn =
                              checkInProvider.getCheckIn(habit.id, DateTime.now());

                          // 左滑删除：使用 Dismissible 实现动画效果
                          return RepaintBoundary(
                            child: Dismissible(
                            key: ValueKey('habit_${habit.id}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await _showDeleteConfirmDialog(context, habit);
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (direction) {
                              _deleteHabit(habit);
                            },
                            child: HabitCard(
                              habit: habit,
                              isCheckedIn: isCheckedIn,
                              checkIn: checkIn,
                              onTap: () => _onHabitTap(habit, isCheckedIn),
                              onLongPress: () => _showHabitDetail(habit, checkIn),
                            ),
                          ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建统计概览卡片
  Widget _buildStatsOverview(
      ThemeData theme, int checked, int total, double rate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日进度', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(rate * 100).toInt()}%',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  total == 0
                      ? '添加习惯开始备考之旅'
                      : checked == total
                          ? '今日已完成，休息一下也没关系'
                          : '稳步前行，一次就好',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            // 进度条
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              '还没有习惯',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 8),
            Text(
              '点击左上角 + 或前往「模板」页添加备考计划\n慢慢来，一次一个好习惯',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 点击习惯卡片：打卡或取消打卡
  void _onHabitTap(Habit habit, bool isCheckedIn) {
    final checkInProvider = context.read<CheckInProvider>();

    if (isCheckedIn) {
      _showCancelCheckInDialog(habit, checkInProvider);
    } else {
      _performCheckIn(habit, checkInProvider);
    }
  }

  /// 执行打卡操作
  Future<void> _performCheckIn(
      Habit habit, CheckInProvider checkInProvider) async {
    HapticFeedback.lightImpact();

    final success = await checkInProvider.checkIn(
      habit.id,
      DateTime.now(),
      null,
      null,
      null,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打卡失败，请稍后重试')),
      );
    }
  }

  /// 显示取消打卡确认弹窗
  void _showCancelCheckInDialog(
      Habit habit, CheckInProvider checkInProvider) {
    final checkIn = checkInProvider.getCheckIn(habit.id, DateTime.now());
    if (checkIn == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消打卡'),
        content: Text('确定取消「${habit.name}」的今日打卡吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () {
              checkInProvider.cancelCheckIn(checkIn.id);
              Navigator.pop(context);
            },
            child: const Text('取消打卡'),
          ),
        ],
      ),
    );
  }

  /// 长按显示习惯详情
  void _showHabitDetail(Habit habit, CheckIn? checkIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${habit.name} - 长按查看详情（待实现）')),
    );
  }

  /// 显示删除确认弹窗
  Future<bool> _showDeleteConfirmDialog(BuildContext context, Habit habit) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除习惯'),
        content: Text('确定删除「${habit.name}」吗？\n删除后将同时清除该习惯的所有打卡记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 删除习惯及其相关打卡记录
  void _deleteHabit(Habit habit) {
    final checkInProvider = context.read<CheckInProvider>();
    final habitCheckIns = checkInProvider.getCheckInsByHabit(habit.id);
    for (final checkIn in habitCheckIns) {
      checkInProvider.cancelCheckIn(checkIn.id);
    }

    context.read<HabitProvider>().removeHabit(habit.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${habit.name}」'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 月历底部弹窗：包裹 MonthCalendarWidget，支持拖拽关闭
class _CalendarSheet extends StatelessWidget {
  const _CalendarSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖拽条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历史打卡',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 月历内容
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: MonthCalendarWidget(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
