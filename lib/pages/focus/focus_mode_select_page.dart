import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../models/habit_model.dart';
import '../../models/whitelist_app_model.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/audio_service.dart';
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

  /// 应用管理 MethodChannel（与 MainActivity.kt 中的 APPS_CHANNEL 对应）
  static const _appsChannel = MethodChannel('com.kaobei.kaobei_punch/apps');

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

                // ===== 结束铃声（仅倒计时模式） =====
                if (focusProvider.mode == FocusMode.countdown) ...[
                  _buildSection(
                    title: '结束铃声',
                    child: _buildRingtoneSelector(focusProvider),
                  ),
                  const SizedBox(height: 24),
                ],

                // ===== 白噪音 =====
                _buildSection(
                  title: '白噪音',
                  child: _buildWhiteNoiseSelector(focusProvider),
                ),

                const SizedBox(height: 24),

                // ===== 白名单应用（严格模式下允许使用的应用，最多 3 个） =====
                _buildSection(
                  title: '白名单应用',
                  child: _buildWhitelistSection(focusProvider),
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

  /// 构建铃声选择器
  Widget _buildRingtoneSelector(FocusProvider provider) {
    final ringtones = RingtoneType.values;
    final hasCustomRingtone = provider.customRingtonePath != null;
    // 始终展示试听按钮：默认 classic 也是有效铃声，应允许试听
    // （原逻辑 selectedRingtone == classic 且无自定义时隐藏试听，导致默认铃声无法试听）

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...ringtones.map((ringtone) {
              final isSelected = provider.selectedRingtone == ringtone && !hasCustomRingtone;
              return _FixedChip(
                selected: isSelected,
                label: Text(
                  AudioService.ringtoneNames[ringtone] ?? ringtone.name,
                ),
                icon: AudioService.ringtoneIcons[ringtone] ?? Icons.notifications_active,
                onTap: () {
                  provider.setRingtone(ringtone);
                },
              );
            }),
            // ===== 自定义铃声按钮 =====
            _FixedChip(
              selected: hasCustomRingtone,
              label: Text(hasCustomRingtone ? '自定义铃声' : '从文件选择'),
              icon: Icons.folder_open,
              onTap: () => provider.pickCustomRingtone(),
            ),
          ],
        ),
        // ===== 试听按钮：始终显示（含默认 classic 铃声）=====
        // 修复问题3：选择自定义铃声后，在试听按钮旁简略显示音频名称
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              icon: Icon(
                provider.isPreviewPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                size: 32,
                color: AppColors.primary,
              ),
              onPressed: () => provider.togglePreview(),
              tooltip: provider.isPreviewPlaying ? '停止试听' : '播放试听',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // 自定义铃声显示文件名，内置铃声显示试听提示
                provider.customRingtonePath != null
                    ? provider.customRingtoneName ?? '自定义铃声'
                    : (provider.isPreviewPlaying ? '点击停止试听' : '点击试听当前铃声'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

  /// 构建白名单应用区块
  ///
  /// 显示当前白名单应用列表（最多 3 个），支持添加与移除。
  /// 添加时通过 MethodChannel 获取系统可启动应用列表供用户选择。
  Widget _buildWhitelistSection(FocusProvider provider) {
    final apps = provider.whitelistApps;
    final max = FocusProvider.kMaxWhitelistApps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 说明文案
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '严格模式下可临时使用的应用，最多 $max 个',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 已添加的白名单应用列表
        if (apps.isEmpty)
          // 空状态提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.lightCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Text(
              '暂未添加白名单应用',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          )
        else
          ...apps.map((app) => _buildWhitelistItem(provider, app)),

        const SizedBox(height: 8),

        // 添加按钮（达到上限时禁用）
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: provider.isWhitelistFull
                ? null
                : () => _showAppPickerDialog(context, provider),
            icon: Icon(Icons.add, size: 18),
            label: Text(
              provider.isWhitelistFull
                  ? '已达上限（$max/$max）'
                  : '添加白名单应用（${apps.length}/$max）',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(
                color: provider.isWhitelistFull
                    ? AppColors.divider
                    : AppColors.primary,
              ),
              foregroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建单个白名单应用条目（含移除按钮）
  Widget _buildWhitelistItem(FocusProvider provider, WhitelistApp app) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lightCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            // 应用图标（异步加载并缓存）
            _AppIcon(packageName: app.packageName),
            const SizedBox(width: 12),
            // 应用名称
            Expanded(
              child: Text(
                app.label,
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 移除按钮
            IconButton(
              icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              onPressed: () => provider.removeWhitelistApp(app.packageName),
              tooltip: '移除',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示应用选择对话框
  ///
  /// 通过 MethodChannel 获取系统所有可启动应用，供用户搜索并添加到白名单。
  Future<void> _showAppPickerDialog(
    BuildContext context,
    FocusProvider provider,
  ) async {
    // 已在白名单中的包名集合（用于过滤已选项）
    final existingPkgs = provider.whitelistApps
        .map((e) => e.packageName)
        .toSet();

    showDialog(
      context: context,
      builder: (ctx) => _AppPickerDialog(
        existingPackages: existingPkgs,
        onSelected: (packageName, label) {
          // 调用 Provider 添加，若超限或重复由 Provider 处理
          final ok = provider.addWhitelistApp(
            WhitelistApp(packageName: packageName, label: label),
          );
          if (ctx.mounted) {
            if (ok) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已添加「$label」到白名单'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('添加失败：白名单已满或应用已存在'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
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

/// 固定尺寸的选择芯片（替代 ChoiceChip，消除选中/未选中时的布局跳动）
///
/// ChoiceChip 在 Material 3 中选中时内边距/阴影会变化导致 Wrap 重排，
/// _FixedChip 使用固定尺寸的 Container，选中/未选中外观完全一致
/// 仅改变背景色和文本颜色以区分状态。
class _FixedChip extends StatelessWidget {
  const _FixedChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final Text label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36, // 固定高度
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : AppColors.lightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              child: label,
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

/// 应用图标组件
///
/// 通过 MethodChannel 异步从 Android 原生层获取应用图标的 Base64 数据，
/// 解码后用 Image.memory 显示。同一包名的图标在进程内缓存，避免重复调用。
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.packageName});

  final String packageName;

  /// 进程内图标缓存：packageName → 已解码字节
  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  @override
  Widget build(BuildContext context) {
    // 命中缓存则直接显示
    final cached = _cache[packageName];
    if (cached != null) {
      return Image.memory(cached, width: 28, height: 28, gaplessPlayback: true);
    }

    // 未命中：FutureBuilder 异步拉取
    return FutureBuilder<Uint8List?>(
      future: _loadIcon(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // 加载中显示占位图标
          return SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.apps,
              size: 24,
              color: AppColors.textHint,
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          // 获取失败：显示默认占位
          return SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.android,
              size: 24,
              color: AppColors.textHint,
            ),
          );
        }
        return Image.memory(bytes, width: 28, height: 28, gaplessPlayback: true);
      },
    );
  }

  /// 通过 MethodChannel 获取应用图标并解码
  Future<Uint8List?> _loadIcon() async {
    if (_cache.containsKey(packageName)) return _cache[packageName];
    try {
      final result = await _FocusModeSelectPageState._appsChannel
          .invokeMethod<String>('getAppIcon', {'packageName': packageName});
      if (result == null || result.isEmpty) {
        _cache[packageName] = null;
        return null;
      }
      final bytes = base64Decode(result);
      _cache[packageName] = bytes;
      return bytes;
    } catch (e) {
      debugPrint('获取应用图标失败: $e');
      _cache[packageName] = null;
      return null;
    }
  }
}

/// 应用选择对话框
///
/// 通过 MethodChannel 一次性拉取系统所有可启动应用，
/// 提供搜索框过滤，点击列表项即选中并回调。
class _AppPickerDialog extends StatefulWidget {
  const _AppPickerDialog({
    required this.existingPackages,
    required this.onSelected,
  });

  /// 已在白名单中的包名集合（这些项将被禁用）
  final Set<String> existingPackages;

  /// 选中应用回调：(packageName, label)
  final void Function(String packageName, String label) onSelected;

  @override
  State<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<_AppPickerDialog> {
  /// 原生返回的应用列表：每项含 packageName 与 label
  List<Map<String, String>> _allApps = <Map<String, String>>[];

  /// 搜索关键字（小写）
  String _query = '';

  /// 是否正在加载
  bool _isLoading = true;

  /// 加载失败的错误信息（null 表示无错误）
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  /// 通过 MethodChannel 拉取可启动应用列表
  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _FocusModeSelectPageState._appsChannel
          .invokeMethod<List>('getLaunchableApps');
      if (result == null) {
        _allApps = <Map<String, String>>[];
      } else {
        // 将原生 Map 动态类型转为强类型 Map<String, String>
        _allApps = result
            .whereType<Map>()
            .map((e) => Map<String, String>.from(e))
            .toList();
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('获取应用列表失败: $e');
      setState(() {
        _isLoading = false;
        _error = '获取应用列表失败，请检查权限';
      });
    }
  }

  /// 根据关键字过滤应用列表
  List<Map<String, String>> get _filteredApps {
    if (_query.isEmpty) return _allApps;
    final q = _query.toLowerCase();
    return _allApps.where((app) {
      final label = (app['label'] ?? '').toLowerCase();
      final pkg = (app['packageName'] ?? '').toLowerCase();
      return label.contains(q) || pkg.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择白名单应用'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 搜索框
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: '搜索应用名称或包名',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim();
                });
              },
            ),
            const SizedBox(height: 12),
            // 列表区域
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }

  /// 构建列表主体（根据状态切换加载/错误/列表）
  Widget _buildBody() {
    if (_isLoading) {
      // 加载动画：圆形进度 + 提示文案，让用户明确知道正在加载应用列表
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '正在加载应用列表...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return Center(
        child: Text(
          '无匹配应用',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: apps.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final app = apps[index];
        final pkg = app['packageName'] ?? '';
        final label = app['label'] ?? '';
        final alreadyAdded = widget.existingPackages.contains(pkg);
        return ListTile(
          leading: _AppIcon(packageName: pkg),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            pkg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          trailing: alreadyAdded
              ? Text(
                  '已添加',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 12,
                  ),
                )
              : Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 22,
                ),
          enabled: !alreadyAdded,
          onTap: alreadyAdded
              ? null
              : () => widget.onSelected(pkg, label),
        );
      },
    );
  }
}