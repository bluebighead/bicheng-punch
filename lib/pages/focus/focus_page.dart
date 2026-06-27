import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../providers/focus_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// 专注页：番茄钟/计时
///
/// 定位：专注模块入口页，展示今日专注统计，引导进入专注模式选择页。
/// 反焦虑：不强调"未完成"，专注一次即正向反馈。
class FocusPage extends StatelessWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 性能优化：原 Consumer<FocusProvider> 在专注会话期间会因 Timer
    // 每秒 notifyListeners 而重建整页（此处仅展示今日次数/时长，无需每秒刷新）。
    // 改用 context.select 精细订阅，仅当所选字段变化时才重建。
    // todayFocusCount / todayFocusDurationText 仅在新专注记录保存后变化，
    // 计时 tick 不会触发本页重建。
    final todayFocusCount =
        context.select<FocusProvider, int>((p) => p.todayFocusCount);
    final todayFocusDurationText =
        context.select<FocusProvider, String>((p) => p.todayFocusDurationText);

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: const Text('专注'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePaddingH),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ===== 今日统计 =====
              _buildTodayStats(todayFocusCount, todayFocusDurationText, theme),

              const SizedBox(height: 48),

              // ===== 快速开始按钮 =====
              _buildQuickStartButton(context),

              const Spacer(),

              // ===== 鼓励文案 =====
              Text(
                '专注即前进，一次就好',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建今日统计
  ///
  /// 性能优化：通过参数显式接收 [todayFocusCount] / [todayFocusDurationText]，
  /// 避免在此方法内访问 provider 触发订阅。
  Widget _buildTodayStats(
      int todayFocusCount, String todayFocusDurationText, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 专注次数
          _StatItem(
            label: '今日专注',
            value: '$todayFocusCount',
            unit: '次',
          ),

          // 分隔线
          Container(
            height: 48,
            width: 1,
            color: AppColors.divider,
          ),

          // 专注时长
          _StatItem(
            label: '累计时长',
            value: todayFocusDurationText,
            unit: '',
          ),
        ],
      ),
    );
  }

  /// 构建快速开始按钮
  ///
  /// 性能优化：mode/targetMinutes 通过 context.read 一次性读取，
  /// 避免订阅 FocusProvider 导致专注期间每秒重建。
  Widget _buildQuickStartButton(BuildContext context) {
    return Column(
      children: [
        // 计时圆环占位
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryLight.withValues(alpha: 0.25),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/focus/mode-select');
            },
            borderRadius: BorderRadius.circular(110),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开始专注',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 快速选择按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _QuickStartChip(
              label: '25 分钟',
              onTap: () {
                // 使用 context.read 避免订阅，此处仅需一次性操作
                final provider = context.read<FocusProvider>();
                provider.setMode(FocusMode.countdown);
                provider.setTargetMinutes(25);
                Navigator.pushNamed(context, '/focus/timer');
              },
            ),
            const SizedBox(width: 12),
            _QuickStartChip(
              label: '自由计时',
              onTap: () {
                final provider = context.read<FocusProvider>();
                provider.setMode(FocusMode.stopwatch);
                Navigator.pushNamed(context, '/focus/timer');
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 快速开始芯片
class _QuickStartChip extends StatelessWidget {
  const _QuickStartChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
