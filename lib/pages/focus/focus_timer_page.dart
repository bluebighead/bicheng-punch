import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../providers/focus_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/focus_timer_ring.dart';
import '../../utils/timer_utils.dart';

/// 专注计时页
///
/// 设计理念：
/// 1. 极简全屏，柔和渐变背景
/// 2. 只有计时圆环和控制按钮
/// 3. 无多余元素干扰
/// 4. 结束时有轻柔提示和正向文案
class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key});

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> with WidgetsBindingObserver {
  bool _hasShownCompletionDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 自动开始专注
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FocusProvider>().startFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 应用从后台恢复时同步计时
    if (state == AppLifecycleState.resumed) {
      context.read<FocusProvider>().syncFromBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitDialog(context);
        }
      },
      child: Consumer<FocusProvider>(
        builder: (context, provider, child) {
          // 监听专注完成状态
          if (provider.timerState == TimerState.completed && !_hasShownCompletionDialog) {
            _hasShownCompletionDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCompletionDialog(context, provider);
            });
          }

          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.15),
                    AppColors.lightBg.withValues(alpha: 0.95),
                    AppColors.secondaryLight.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // ===== 顶部工具栏 =====
                    _buildTopBar(provider),

                    // ===== 主体内容 =====
                    Expanded(
                      child: Center(
                        child: _buildTimerContent(provider),
                      ),
                    ),

                    // ===== 底部控制按钮 =====
                    _buildBottomControls(provider),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建顶部工具栏
  Widget _buildTopBar(FocusProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePaddingH,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 白噪音状态
          if (provider.whiteNoiseEnabled && provider.whiteNoiseType != null)
            _buildNoiseIndicator(provider),

          const Spacer(),

          // 已计时时长（正计时模式）
          if (provider.mode == FocusMode.stopwatch)
            Text(
              '已专注 ${_formatDuration(provider.elapsedSeconds)}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// 构建白噪音指示器
  Widget _buildNoiseIndicator(FocusProvider provider) {
    final noiseNames = {
      WhiteNoiseType.rain: '雨声',
      WhiteNoiseType.cafe: '咖啡馆',
      WhiteNoiseType.music: '纯音乐',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            noiseNames[provider.whiteNoiseType!] ?? '',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建计时内容
  Widget _buildTimerContent(FocusProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 计时圆环
        FocusTimerRing(
          elapsedSeconds: provider.elapsedSeconds,
          targetSeconds: provider.mode == FocusMode.countdown
              ? provider.targetMinutes * 60
              : null,
          isCountdown: provider.mode == FocusMode.countdown,
          size: 280,
          strokeWidth: 8,
        ),

        const SizedBox(height: 32),

        // 关联习惯提示
        if (provider.linkedHabit != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '正在为「${provider.linkedHabit!.name}」专注',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// 构建底部控制按钮
  Widget _buildBottomControls(FocusProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePaddingH,
        vertical: 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 暂停/继续按钮
          if (provider.timerState == TimerState.running)
            _ControlButton(
              icon: Icons.pause,
              label: '暂停',
              onPressed: () => provider.pauseFocus(),
            )
          else if (provider.timerState == TimerState.paused)
            _ControlButton(
              icon: Icons.play_arrow,
              label: '继续',
              onPressed: () => provider.resumeFocus(),
            ),

          const SizedBox(width: 32),

          // 停止按钮
          _ControlButton(
            icon: Icons.stop,
            label: '结束',
            onPressed: () => _showStopDialog(provider),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  /// 显示退出确认对话框
  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出？'),
        content: const Text('退出后将结束本次专注，已专注时长将保存到记录中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续专注'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<FocusProvider>().stopFocus();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              '退出',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示停止确认对话框
  void _showStopDialog(FocusProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束专注？'),
        content: Text('本次已专注 ${_formatDuration(provider.elapsedSeconds)}，确定要结束吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.stopFocus();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示完成对话框
  void _showCompletionDialog(BuildContext context, FocusProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              '又完成了一段高效学习，很棒！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '本次专注 ${_formatDuration(provider.elapsedSeconds)}',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            if (provider.linkedHabit != null) ...[
              const SizedBox(height: 8),
              Text(
                '可自动完成「${provider.linkedHabit!.name}」打卡',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // 自动打卡
              if (provider.linkedHabit != null) {
                final checkInProvider = context.read<CheckInProvider>();
                await checkInProvider.checkIn(
                  provider.linkedHabit!.id,
                  DateTime.now(),
                  null,
                  null,
                  provider.elapsedSeconds ~/ 60,
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours 小时 $minutes 分钟';
    } else {
      final minutes = seconds ~/ 60;
      return '$minutes 分钟';
    }
  }
}

/// 控制按钮
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.15)
              : AppColors.primaryLight.withValues(alpha: 0.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: isDestructive ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDestructive ? AppColors.error : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}