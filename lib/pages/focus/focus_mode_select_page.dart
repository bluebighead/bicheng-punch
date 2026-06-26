import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../models/habit_model.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// 专注模式选择页
///
/// 功能：
/// 1. 选择专注模式（正计时/倒计时）
/// 2. 设置倒计时时长（5-180分钟，支持自定义）
/// 3. 选择关联习惯
/// 4. 配置白噪音
class FocusModeSelectPage extends StatefulWidget {
  const FocusModeSelectPage({super.key});

  @override
  State<FocusModeSelectPage> createState() => _FocusModeSelectPageState();
}

class _FocusModeSelectPageState extends State<FocusModeSelectPage> {
  final TextEditingController _customDurationController = TextEditingController();

  @override
  void dispose() {
    _customDurationController.dispose();
    super.dispose();
  }

  /// 显示自定义时长输入弹窗
  void _showCustomDurationDialog(BuildContext context, FocusProvider provider) {
    _customDurationController.text = provider.targetMinutes.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义时长'),
        content: TextField(
          controller: _customDurationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '专注时长（分钟）',
            hintText: '输入 5-180 之间的整数',
            suffixText: '分钟',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final input = _customDurationController.text.trim();
              final minutes = int.tryParse(input);
              if (minutes != null && minutes >= 5 && minutes <= 180) {
                provider.setTargetMinutes(minutes);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请输入 5-180 之间的整数'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('开始专注'),
      ),
      body: Consumer2<FocusProvider, HabitProvider>(
        builder: (context, focusProvider, habitProvider, child) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.pagePaddingH,
                vertical: 16,
              ),
              children: [
                // ===== 专注模式选择 =====
                _buildSection(
                  title: '专注模式',
                  child: _buildModeSelector(focusProvider),
                ),

                const SizedBox(height: 24),

                // ===== 时长设置（倒计时模式） =====
                if (focusProvider.mode == FocusMode.countdown) ...[
                  _buildSection(
                    title: '专注时长',
                    child: _buildDurationSelector(focusProvider),
                  ),
                  const SizedBox(height: 24),
                ],

                // ===== 关联习惯 =====
                _buildSection(
                  title: '关联习惯',
                  child: _buildHabitSelector(focusProvider, habitProvider),
                ),

                const SizedBox(height: 24),

                // ===== 白噪音 =====
                _buildSection(
                  title: '白噪音',
                  child: _buildWhiteNoiseSelector(focusProvider),
                ),

                const SizedBox(height: 32),

                // ===== 开始按钮 =====
                _buildStartButton(context, focusProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建区块
  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  /// 构建模式选择器
  Widget _buildModeSelector(FocusProvider provider) {
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            title: '倒计时',
            subtitle: '番茄钟模式',
            icon: Icons.timer,
            isSelected: provider.mode == FocusMode.countdown,
            onTap: () => provider.setMode(FocusMode.countdown),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeCard(
            title: '正计时',
            subtitle: '自由模式',
            icon: Icons.timer_outlined,
            isSelected: provider.mode == FocusMode.stopwatch,
            onTap: () => provider.setMode(FocusMode.stopwatch),
          ),
        ),
      ],
    );
  }

  /// 构建时长选择器
  Widget _buildDurationSelector(FocusProvider provider) {
    final durations = [5, 15, 25, 30, 45, 60, 90, 120, 180];
    final isCustom = !durations.contains(provider.targetMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...durations.map((minutes) {
              final isSelected = provider.targetMinutes == minutes;
              return ChoiceChip(
                label: Text('$minutes 分钟'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    provider.setTargetMinutes(minutes);
                  }
                },
                selectedColor: AppColors.primaryLight.withValues(alpha: 0.4),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              );
            }),
            // 自定义时长选项
            ChoiceChip(
              label: Text(isCustom ? '${provider.targetMinutes} 分钟' : '自定义'),
              selected: isCustom,
              onSelected: (selected) {
                if (selected) {
                  _showCustomDurationDialog(context, provider);
                }
              },
              selectedColor: AppColors.primaryLight.withValues(alpha: 0.4),
              labelStyle: TextStyle(
                color: isCustom ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isCustom ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建习惯选择器
  Widget _buildHabitSelector(
    FocusProvider provider,
    HabitProvider habitProvider,
  ) {
    final habits = habitProvider.activeHabits;

    if (habits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Text(
              '暂无习惯可关联',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 不关联选项
        _HabitChip(
          habit: null,
          isSelected: provider.linkedHabit == null,
          onTap: () => provider.setLinkedHabit(null),
        ),
        const SizedBox(height: 8),
        // 习惯列表
        ...habits.map((habit) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HabitChip(
              habit: habit,
              isSelected: provider.linkedHabit?.id == habit.id,
              onTap: () => provider.setLinkedHabit(habit),
            ),
          );
        }),
      ],
    );
  }

  /// 构建白噪音选择器
  Widget _buildWhiteNoiseSelector(FocusProvider provider) {
    final noises = [
      WhiteNoiseType.rain,
      WhiteNoiseType.cafe,
      WhiteNoiseType.music,
    ];

    final noiseNames = {
      WhiteNoiseType.rain: '雨声',
      WhiteNoiseType.cafe: '咖啡馆',
      WhiteNoiseType.music: '纯音乐',
    };

    final noiseIcons = {
      WhiteNoiseType.rain: Icons.water_drop_outlined,
      WhiteNoiseType.cafe: Icons.coffee_outlined,
      WhiteNoiseType.music: Icons.music_note_outlined,
    };

    return Column(
      children: [
        // 白噪音开关
        SwitchListTile(
          title: const Text('启用白噪音'),
          value: provider.whiteNoiseEnabled,
          onChanged: (_) => provider.toggleWhiteNoise(),
          contentPadding: EdgeInsets.zero,
        ),
        if (provider.whiteNoiseEnabled) ...[
          const SizedBox(height: 12),
          // 白噪音类型选择
          Row(
            children: noises.map((noise) {
              final isSelected = provider.whiteNoiseType == noise;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: noise != noises.last ? 8 : 0,
                  ),
                  child: _NoiseCard(
                    title: noiseNames[noise]!,
                    icon: noiseIcons[noise]!,
                    isSelected: isSelected,
                    onTap: () => provider.setWhiteNoiseType(noise),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // 音量调节
          Row(
            children: [
              Icon(Icons.volume_down, size: 20, color: AppColors.textSecondary),
              Expanded(
                child: Slider(
                  value: provider.volume,
                  onChanged: (value) => provider.setVolume(value),
                  min: 0,
                  max: 1,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              Icon(Icons.volume_up, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建开始按钮
  Widget _buildStartButton(BuildContext context, FocusProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/focus/timer',
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('开始专注'),
      ),
    );
  }
}

/// 模式选择卡片
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.25)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 将字符串图标名转为 IconData
IconData _iconFromString(String iconName) {
  switch (iconName) {
    case 'menu_book':
      return Icons.menu_book;
    case 'calculate':
      return Icons.calculate;
    case 'school':
      return Icons.school;
    case 'article':
      return Icons.article;
    case 'quiz':
      return Icons.quiz;
    case 'edit_note':
      return Icons.edit_note;
    case 'lightbulb':
      return Icons.lightbulb;
    case 'psychology':
      return Icons.psychology;
    case 'fact_check':
      return Icons.fact_check;
    case 'description':
      return Icons.description;
    case 'translate':
      return Icons.translate;
    case 'headphones':
      return Icons.headphones;
    case 'auto_stories':
      return Icons.auto_stories;
    default:
      return Icons.check_circle_outline;
  }
}

/// 习惯选择卡片
class _HabitChip extends StatelessWidget {
  const _HabitChip({
    required this.habit,
    required this.isSelected,
    required this.onTap,
  });

  final Habit? habit;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.25)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              habit != null
                  ? _iconFromString(habit!.icon)
                  : Icons.block,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              habit?.name ?? '不关联习惯',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// 白噪音选择卡片
class _NoiseCard extends StatelessWidget {
  const _NoiseCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.25)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}