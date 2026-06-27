import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/habit_model.dart';
import '../../models/check_in_model.dart';

/// 习惯卡片组件
///
/// 设计原则：
/// - 未打卡：柔和的边框样式，轻盈感
/// - 已打卡：柔和填充色，搭配圆角图标，无夸张动画
/// - 点击打卡时震动反馈（HapticFeedback.lightImpact）
/// - 长按可查看详情/编辑备注/上传图片
class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.isCheckedIn,
    this.checkIn,
    required this.onTap,
    required this.onLongPress,
    this.batchMode = false,
    this.isSelected = false,
    this.onSelectToggle,
  });

  final Habit habit;
  final bool isCheckedIn;
  final CheckIn? checkIn;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  // ===== 批量模式相关参数 =====
  /// 是否处于批量模式（true 时显示复选框，点击切换选中而非打卡）
  final bool batchMode;

  /// 当前是否被选中（仅 batchMode=true 时有效）
  final bool isSelected;

  /// 复选框点击回调（仅 batchMode=true 时触发）
  final VoidCallback? onSelectToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitColor = Color(habit.color);

    // 已打卡样式：柔和填充 + 圆角图标
    // 未打卡样式：轻盈边框 + 图标置顶
    final targetDecoration = isCheckedIn
        ? BoxDecoration(
            color: habitColor.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
            border: Border.all(
              color: habitColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          )
        : BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
            border: Border.all(
              color: AppColors.divider,
              width: 1,
            ),
          );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      // 性能优化：原 AnimatedContainer 在主题切换时会触发 350ms 动画，
      // 所有卡片同时动画导致掉帧。改用普通 Container，
      // 主题切换时瞬时更新颜色，避免多卡片并发动画。
      // （打卡状态的视觉反馈已通过颜色变化体现，无需额外过渡动画）
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: targetDecoration,
        child: Row(
          children: [
            // 图标区域（批量模式下替换为复选框）
            if (batchMode)
              GestureDetector(
                onTap: onSelectToggle,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.lightCard,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check : null,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? habitColor.withValues(alpha: 0.3)
                      : habitColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(
                  _getIconData(habit.icon),
                  color: isCheckedIn ? habitColor : AppColors.textPrimary,
                  size: 22,
                ),
              ),

            const SizedBox(width: 16),

            // 习惯名称 + 频率信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isCheckedIn
                          ? habitColor
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getFrequencyText(habit),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),

            // 状态标记（批量模式下隐藏，避免与复选框重复）
            if (!batchMode) ...[
              if (isCheckedIn)
                Icon(
                  Icons.check_circle,
                  color: habitColor,
                  size: 24,
                )
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: AppColors.textHint,
                  size: 24,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 获取图标数据（根据字符串名称映射到 Material Icon）
  IconData _getIconData(String iconName) {
    final iconMap = {
      'menu_book': Icons.menu_book,
      'calculate': Icons.calculate,
      'school': Icons.school,
      'article': Icons.article,
      'quiz': Icons.quiz,
      'edit_note': Icons.edit_note,
      'lightbulb': Icons.lightbulb,
      'psychology': Icons.psychology,
      'fact_check': Icons.fact_check,
      'description': Icons.description,
      'translate': Icons.translate,
      'headphones': Icons.headphones,
      'auto_stories': Icons.auto_stories,
      'fitness_center': Icons.fitness_center,
      'book': Icons.book,
      'create': Icons.create,
      'error_outline': Icons.error_outline,
    };
    return iconMap[iconName] ?? Icons.task_alt;
  }

  /// 获取频率描述文本
  String _getFrequencyText(Habit habit) {
    switch (habit.frequencyType) {
      case FrequencyType.daily:
        return '每日';
      case FrequencyType.weeklyX:
        return '每周 ${habit.weeklyCount} 次';
      case FrequencyType.customDays:
        final days = habit.customDays.map((d) => _weekdayText(d)).join('/');
        return '每周 $days';
    }
  }

  /// 周几转文字
  String _weekdayText(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }
}