import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../models/whitelist_app_model.dart';
import '../../providers/focus_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../services/audio_service.dart';
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

  // ===== 严格模式授权待启用标志 =====
  // 用户首次开启严格模式但未授权「使用情况访问」时，跳转系统设置授权。
  // 此标志记录"授权返回后需自动启用严格模式"的待办状态，
  // 在 didChangeAppLifecycleState 的 resumed 分支中检查并自动启用。
  bool _pendingStrictModeEnable = false;

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

    // 恢复系统 UI 设置
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 应用从后台恢复时同步计时
    if (state == AppLifecycleState.resumed) {
      context.read<FocusProvider>().syncFromBackground();

      // 修复：若用户刚从系统「使用情况访问」设置页返回，
      // 重新检测权限，已授权则自动启用严格模式（无需用户手动再开关一次）
      if (_pendingStrictModeEnable) {
        _pendingStrictModeEnable = false;
        _resumePendingStrictModeEnable();
      }
    }
  }

  /// 授权返回后自动启用严格模式
  ///
  /// 修复问题1：原实现授权返回后不自动启用，需用户手动再开关一次。
  /// 现改为：检测到已授权则直接调用 _enableStrictMode，未授权则回退开关。
  /// 同时检查使用情况访问权限和辅助功能权限。
  Future<void> _resumePendingStrictModeEnable() async {
    bool hasAccess = false;
    bool hasAccessibility = false;
    try {
      hasAccess =
          await _appsChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      hasAccessibility =
          await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      debugPrint('授权返回后检查权限失败: $e');
    }

    if (!mounted) return;

    final provider = context.read<FocusProvider>();
    if (hasAccess && hasAccessibility) {
      // 两个权限都已授权：自动启用严格模式
      _enableStrictMode(context, provider);
    } else {
      // 未授权：回退开关状态并提示
      provider.setStrictMode(false);
      if (mounted) {
        final missing = <String>[];
        if (!hasAccess) missing.add('使用情况访问');
        if (!hasAccessibility) missing.add('无障碍');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('未授予${missing.join('和')}权限，严格模式未开启'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 性能优化：原 Consumer<FocusProvider> 在 Timer 每秒 notifyListeners 时
    // 重建整页（含 PopScope/Scaffold/Container 渐变背景/Column/底部按钮等）。
    // 实际只有"圆环 + 已专注文本"依赖 elapsedSeconds。
    // 拆分订阅：
    //   - 状态字段（timerState/strictMode/mode/linkedHabit/whiteNoise*/菜单配置等）
    //     用 context.select 精细订阅，秒级 tick 不会触发这些位置的重建。
    //   - elapsedSeconds 用专门的 Selector，仅圆环与已专注文本每秒刷新。
    final timerState =
        context.select<FocusProvider, TimerState>((p) => p.timerState);
    final strictMode =
        context.select<FocusProvider, bool>((p) => p.strictMode);
    final mode =
        context.select<FocusProvider, FocusMode>((p) => p.mode);
    final targetMinutes =
        context.select<FocusProvider, int>((p) => p.targetMinutes);
    final linkedHabitId =
        context.select<FocusProvider, String?>((p) => p.linkedHabit?.id);
    final whiteNoiseEnabled =
        context.select<FocusProvider, bool>((p) => p.whiteNoiseEnabled);
    final whiteNoiseType =
        context.select<FocusProvider, WhiteNoiseType?>((p) => p.whiteNoiseType);

    // 监听专注完成状态：仅在状态变化为 completed 时触发一次对话框
    if (timerState == TimerState.completed && !_hasShownCompletionDialog) {
      _hasShownCompletionDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<FocusProvider>();
        // 修复问题5：倒计时结束自动退出严格模式，恢复正常
        // 原实现未在完成时关闭严格模式，导致锁屏状态残留
        if (provider.strictMode) {
          provider.setStrictMode(false);
          _disableStrictMode(context);
        }
        _showCompletionDialog(context, provider);
      });
    }

    return PopScope(
      // 始终拦截返回手势：无论是否严格模式，都需经确认后才能退出，
      // 否则非严格模式下直接返回会导致专注记录丢失、屏幕常亮未关闭。
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (strictMode) {
          // 严格模式下：不做任何操作，提示用户
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('严格模式下无法返回'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        } else if (timerState == TimerState.running ||
            timerState == TimerState.paused) {
          // 正在专注/暂停中：显示退出确认对话框
          _showExitDialog(context);
        } else {
          // 已完成或空闲：直接返回
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                // 顶部工具栏依赖 whiteNoise*/mode 等，但不依赖 elapsedSeconds
                // （正计时模式下"已专注 X"文本通过下方 _StopwatchElapsed 单独订阅）
                _buildTopBar(
                  whiteNoiseEnabled: whiteNoiseEnabled,
                  whiteNoiseType: whiteNoiseType,
                  mode: mode,
                ),

                // ===== 主体内容 =====
                Expanded(
                  child: Center(
                    // 圆环 + 关联习惯文本：仅这部分每秒重建
                    child: _buildTimerContent(
                      context: context,
                      mode: mode,
                      targetMinutes: targetMinutes,
                      linkedHabitId: linkedHabitId,
                    ),
                  ),
                ),

                // ===== 底部控制按钮 =====
                // 底部按钮只依赖 timerState，秒级 tick 不触发重建
                _buildBottomControls(
                  timerState: timerState,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建顶部工具栏
  ///
  /// 性能优化：参数化接收所需字段，避免在此处访问 provider 触发订阅。
  /// "已专注 X" 文本依赖 elapsedSeconds，单独用 [Selector] 包裹，
  /// 秒级 tick 仅刷新该 Text，不波及菜单按钮等兄弟节点。
  Widget _buildTopBar({
    required bool whiteNoiseEnabled,
    required WhiteNoiseType? whiteNoiseType,
    required FocusMode mode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePaddingH,
        vertical: 12,
      ),
      child: Row(
        children: [
          // 白噪音状态
          if (whiteNoiseEnabled && whiteNoiseType != null)
            _buildNoiseIndicator(whiteNoiseType),

          const Spacer(),

          // 已计时时长（正计时模式）—— 秒级 tick 仅刷新该 Text
          if (mode == FocusMode.stopwatch)
            Selector<FocusProvider, int>(
              selector: (_, p) => p.elapsedSeconds,
              builder: (context, elapsed, _) {
                return Text(
                  '已专注 ${_formatDuration(elapsed)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),

          const SizedBox(width: 8),

          // ===== 右上角汉堡菜单按钮 =====
          // 菜单按钮内容（铃声名/严格模式/白名单数量）依赖 provider 状态，
          // 但 PopupMenuButton 只在点击时展开 itemBuilder，菜单内容在打开瞬间
          // 通过 context.read 读取最新值即可，平时不订阅 elapsedSeconds。
          _buildMenuButton(context),
        ],
      ),
    );
  }

  /// 构建白噪音指示器
  ///
  /// 性能优化：参数化接收 whiteNoiseType，避免在此处订阅整个 provider
  Widget _buildNoiseIndicator(WhiteNoiseType whiteNoiseType) {
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
            noiseNames[whiteNoiseType] ?? '',
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

  /// 构建右上角汉堡菜单按钮（三层堆叠菜单图标）
  ///
  /// 性能优化：菜单内容（铃声名/严格模式开关/白名单数量）在弹窗打开瞬间
  /// 通过 context.read 一次性读取最新值，平时不订阅 elapsedSeconds。
  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.menu,
        color: AppColors.textPrimary,
        size: 24,
      ),
      tooltip: '更多设置',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      onSelected: (value) {
        // 弹窗选项触发时一次性读取 provider
        final provider = context.read<FocusProvider>();
        switch (value) {
          case 'ringtone':
            _showRingtonePicker(context, provider);
            break;
          case 'strict_mode':
            provider.toggleStrictMode();
            _onStrictModeChanged(context, provider);
            break;
          case 'whitelist':
            _showWhitelistPanel(context, provider);
            break;
        }
      },
      itemBuilder: (context) {
        // 菜单展开瞬间一次性读取最新状态，避免平时订阅 elapsedSeconds
        final provider = context.read<FocusProvider>();
        return [
          // ===== 铃声设置 =====
          PopupMenuItem<String>(
            value: 'ringtone',
            child: Row(
              children: [
                Icon(
                  provider.customRingtonePath != null
                      ? Icons.audio_file
                      : (AudioService.ringtoneIcons[provider.selectedRingtone] ?? Icons.notifications_active),
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                // 使用 Flexible 约束宽度，过长时截断
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '结束铃声',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        provider.customRingtonePath != null
                            ? provider.customRingtonePath!.split('\\').last.split('/').last
                            : (AudioService.ringtoneNames[provider.selectedRingtone] ?? '经典提示音'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),

          // ===== 分隔线 =====
          const PopupMenuDivider(),

          // ===== 严格模式开关 =====
          PopupMenuItem<String>(
            value: 'strict_mode',
            child: Row(
              children: [
                Icon(
                  provider.strictMode ? Icons.lock : Icons.lock_open,
                  size: 20,
                  color: provider.strictMode ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '严格模式',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: provider.strictMode,
                  onChanged: (value) {
                    // 关闭 PopupMenu
                    Navigator.pop(context);
                    // 切换严格模式
                    provider.setStrictMode(value);
                    _onStrictModeChanged(context, provider);
                  },
                  activeThumbColor: AppColors.error,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),

          // ===== 分隔线 =====
          const PopupMenuDivider(),

          // ===== 白名单应用 =====
          PopupMenuItem<String>(
            value: 'whitelist',
            child: Row(
              children: [
                Icon(
                  Icons.apps,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '白名单应用',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '已添加 ${provider.whitelistApps.length}/${FocusProvider.kMaxWhitelistApps} 个',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  /// 显示铃声选择弹窗
  void _showRingtonePicker(BuildContext context, FocusProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusL),
          topRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePaddingH,
              vertical: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.music_note,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '选择结束铃声',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 铃声列表
                ...RingtoneType.values.map((ringtone) {
                  final isSelected = provider.selectedRingtone == ringtone && provider.customRingtonePath == null;
                  return ListTile(
                    leading: Icon(
                      AudioService.ringtoneIcons[ringtone] ?? Icons.notifications_active,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    title: Text(
                      AudioService.ringtoneNames[ringtone] ?? ringtone.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                        : IconButton(
                            icon: Icon(
                              Icons.play_circle_outline,
                              color: AppColors.textHint,
                              size: 20,
                            ),
                            onPressed: () async {
                              // 试听前先停止当前播放，避免连续点击导致音频重叠
                              await AudioService().stopPreview();
                              await AudioService().playCompletionSound(ringtone);
                            },
                          ),
                    selected: isSelected,
                    onTap: () {
                      provider.setRingtone(ringtone);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                // ===== 自定义铃声 =====
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.folder_open,
                    color: provider.customRingtonePath != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    '从手机选择音频文件',
                    style: TextStyle(
                      fontWeight: provider.customRingtonePath != null ? FontWeight.w600 : FontWeight.w400,
                      color: provider.customRingtonePath != null ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: provider.customRingtonePath != null
                      ? Text(
                          provider.customRingtonePath!.split('\\').last.split('/').last,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: provider.customRingtonePath != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_circle_outline, color: AppColors.textHint, size: 20),
                              onPressed: () async {
                                // 试听前先停止当前播放，避免音频重叠
                                await AudioService().stopPreview();
                                await AudioService().playCompletionSoundFromFile(provider.customRingtonePath!);
                              },
                            ),
                            Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        )
                      : null,
                  onTap: () async {
                    // 等待原生文件选择器返回后再关闭弹窗：
                    // 原逻辑未 await 导致弹窗先关、原生选择器后弹，流程割裂
                    await provider.pickCustomRingtone();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
      // 弹窗关闭时（选择铃声、点空白、返回键）停止试听铃声，
      // 避免弹窗已关但试听音乐继续播放的问题
    ).whenComplete(() {
      AudioService().stopPreview();
    });
  }

  /// 严格模式变更处理
  void _onStrictModeChanged(BuildContext context, FocusProvider provider) {
    if (provider.strictMode) {
      // 启用严格模式：先检查「使用情况访问」权限
      _ensureUsageAccessThenEnable(context, provider);
    } else {
      // 禁用严格模式：解锁
      _disableStrictMode(context);
    }
  }

  /// 检查「使用情况访问」权限，未授权则引导用户前往设置
  ///
  /// StrictMonitorService 依赖 UsageStatsManager 监控前台应用，
  /// 该 API 需用户在系统设置中授予「使用情况访问」权限。
  /// 同时检查辅助功能权限（用于监听窗口切换并自动返回）。
  Future<void> _ensureUsageAccessThenEnable(
    BuildContext context,
    FocusProvider provider,
  ) async {
    bool hasAccess = false;
    bool hasAccessibility = false;
    try {
      hasAccess = await _appsChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      // 检查辅助功能权限（通过 strict_mode channel）
      hasAccessibility =
          await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } catch (e) {
      debugPrint('检查权限失败: $e');
    }

    if (!context.mounted) return;

    // 优先检查使用情况访问权限
    if (!hasAccess) {
      _showUsageAccessDialog(context, provider);
      return;
    }

    // 再检查辅助功能权限
    if (!hasAccessibility) {
      _showAccessibilityDialog(context, provider);
      return;
    }

    // 两个权限都已授权：直接启用严格模式
    _enableStrictMode(context, provider);
  }

  /// 显示辅助功能权限引导对话框
  ///
  /// 严格模式依赖辅助服务监听窗口切换事件，
  /// 检测到非白名单应用时自动执行返回动作拉回专注界面。
  /// 用户需在系统无障碍设置中手动开启本服务。
  void _showAccessibilityDialog(
    BuildContext context,
    FocusProvider provider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Row(
          children: [
            Icon(Icons.accessibility_new, color: AppColors.primary),
            SizedBox(width: 8),
            Text('需要两项权限'),
          ],
        ),
        content: const Text(
          '严格模式需要两项权限：\n\n'
          '1. 无障碍服务：检测应用切换\n\n'
          '2. 悬浮窗权限：覆盖非白名单应用\n'
          '（MIUI 系统限制，必须用悬浮窗阻止桌面）\n\n'
          '请先开启无障碍服务，再授予悬浮窗权限。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.setStrictMode(false);
              Navigator.pop(dialogContext);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              _pendingStrictModeEnable = true;
              try {
                await _channel.invokeMethod('openOverlaySettings');
              } catch (e) {
                debugPrint('打开无障碍设置失败: $e');
                _pendingStrictModeEnable = false;
                if (mounted) {
                  provider.setStrictMode(false);
                }
              }
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 显示「使用情况访问」权限引导对话框
  void _showUsageAccessDialog(
    BuildContext context,
    FocusProvider provider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: AppColors.primary),
            SizedBox(width: 8),
            Text('需要使用情况访问权限'),
          ],
        ),
        content: const Text(
          '严格模式需要「使用情况访问」权限来监控当前正在使用的应用，'
          '以便在您切换到非白名单应用时自动拉回专注界面。\n\n'
          '请在接下来的系统设置页面中，找到「笔程」并授权。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 用户取消：回退严格模式开关状态
              provider.setStrictMode(false);
              Navigator.pop(dialogContext);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // 设置待启用标志：授权返回后自动检测并启用严格模式
              _pendingStrictModeEnable = true;
              // 跳转到系统「使用情况访问」设置页
              try {
                await _appsChannel.invokeMethod('openUsageAccessSettings');
              } catch (e) {
                debugPrint('打开使用情况设置失败: $e');
                _pendingStrictModeEnable = false;
                if (mounted) {
                  provider.setStrictMode(false);
                }
              }
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 启用严格模式
  void _enableStrictMode(BuildContext context, FocusProvider provider) {
    // 1. 隐藏系统状态栏和导航栏（沉浸模式）
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // 2. 锁定屏幕方向为竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 3. 通过 MethodChannel 通知 Android 原生层锁定任务
    //    同时传递白名单包名列表，StrictMonitorService 会据此放行白名单应用
    _invokeAndroidMethod(
      'enableStrictMode',
      arguments: <String, dynamic>{
        'whitelist': provider.whitelistPackageNames,
      },
    );

    // 4. 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('已开启严格模式，将锁定所有操作'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.error,
      ),
    );
  }

  /// 禁用严格模式
  void _disableStrictMode(BuildContext context) {
    // 1. 恢复系统导航栏和状态栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    // 2. 恢复屏幕方向锁定
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 3. 通过 MethodChannel 通知 Android 原生层停止监控
    _invokeAndroidMethod('disableStrictMode');

    // 4. 同步 Provider 状态（避免 UI 仍显示严格模式开启）
    context.read<FocusProvider>().setStrictMode(false);

    // 5. 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('已关闭严格模式'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 调用 Android 原生 MethodChannel
  static const _channel = MethodChannel('com.kaobei.kaobei_punch/strict_mode');

  /// 应用管理 MethodChannel（与 MainActivity.kt 中的 APPS_CHANNEL 对应）
  static const _appsChannel = MethodChannel('com.kaobei.kaobei_punch/apps');

  static Future<void> _invokeAndroidMethod(
    String method, {
    Map<String, dynamic>? arguments,
  }) async {
    try {
      await _channel.invokeMethod(method, arguments);
    } catch (e) {
      debugPrint('Android 原生方法调用失败: $e');
      // 失败不阻塞，Flutter 侧仍然执行沉浸模式等操作
    }
  }

  /// 显示白名单应用悬浮面板
  ///
  /// 列出当前白名单应用，点击即通过原生 MethodChannel 启动对应应用。
  /// 在严格模式下，StrictMonitorService 会放行白名单应用，禁止其他应用。
  void _showWhitelistPanel(BuildContext context, FocusProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusL),
          topRight: Radius.circular(AppTheme.radiusL),
        ),
      ),
      builder: (ctx) {
        final apps = provider.whitelistApps;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pagePaddingH,
              vertical: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Icon(Icons.apps, size: 22, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      '白名单应用',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // 严格模式状态标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: provider.strictMode
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.strictMode ? '严格模式中' : '严格模式未开启',
                        style: TextStyle(
                          fontSize: 11,
                          color: provider.strictMode
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 说明文案
                Text(
                  provider.strictMode
                      ? '点击应用图标打开，其他应用将被拦截'
                      : '开启严格模式后，仅白名单应用可使用',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 16),
                // 应用列表 / 空状态
                if (apps.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AppColors.lightCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '尚未添加白名单应用',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '请在「开始专注」页设置',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return _WhitelistAppTile(
                        app: app,
                        onTap: () => _launchWhitelistApp(context, app),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                // 关闭按钮
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 通过 MethodChannel 启动白名单应用
  Future<void> _launchWhitelistApp(
    BuildContext context,
    WhitelistApp app,
  ) async {
    try {
      final ok = await _appsChannel.invokeMethod<bool>(
        'launchApp',
        {'packageName': app.packageName},
      );
      if (!context.mounted) return;
      if (ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在打开「${app.label}」'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动「${app.label}」失败'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('启动白名单应用失败: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('启动「${app.label}」失败: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 构建计时内容
  ///
  /// 性能优化：圆环依赖 elapsedSeconds，单独用 [Selector] 包裹，
  /// 秒级 tick 仅重建圆环本身，不波及关联习惯提示文本与父级布局。
  /// 关联习惯名通过 [linkedHabitId] 在父级订阅，仅当切换习惯时才重建。
  Widget _buildTimerContent({
    required BuildContext context,
    required FocusMode mode,
    required int targetMinutes,
    required String? linkedHabitId,
  }) {
    // 通过 id 反查习惯名（id 不变则 name 不变，Selector 不会触发重建）
    final linkedHabitName = linkedHabitId == null
        ? null
        : context.read<FocusProvider>().linkedHabit?.name;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 计时圆环 —— 仅这部分每秒重建
        Selector<FocusProvider, int>(
          selector: (_, p) => p.elapsedSeconds,
          builder: (context, elapsed, _) {
            return FocusTimerRing(
              elapsedSeconds: elapsed,
              targetSeconds: mode == FocusMode.countdown
                  ? targetMinutes * 60
                  : null,
              isCountdown: mode == FocusMode.countdown,
              size: 280,
              strokeWidth: 8,
            );
          },
        ),

        const SizedBox(height: 32),

        // 关联习惯提示（仅当切换习惯时变化）
        if (linkedHabitName != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '正在为「$linkedHabitName」专注',
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
  ///
  /// 性能优化：底部按钮只依赖 timerState，秒级 tick 不会触发重建。
  /// 按钮回调通过 context.read 一次性获取 provider 调用相应方法。
  Widget _buildBottomControls({required TimerState timerState}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePaddingH,
        vertical: 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 暂停/继续按钮
          if (timerState == TimerState.running)
            _ControlButton(
              icon: Icons.pause,
              label: '暂停',
              onPressed: () => context.read<FocusProvider>().pauseFocus(),
            )
          else if (timerState == TimerState.paused)
            _ControlButton(
              icon: Icons.play_arrow,
              label: '继续',
              onPressed: () => context.read<FocusProvider>().resumeFocus(),
            ),

          const SizedBox(width: 32),

          // 停止按钮
          _ControlButton(
            icon: Icons.stop,
            label: '结束',
            onPressed: () =>
                _showStopDialog(context.read<FocusProvider>()),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认退出？'),
        content: const Text('退出后将结束本次专注，已专注时长将保存到记录中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('继续专注'),
          ),
          TextButton(
            onPressed: () async {
              // 先关闭对话框，再用页面 context 执行后续操作
              Navigator.pop(dialogContext);
              // 结束计时时自动关闭严格模式（若已开启）
              final provider = context.read<FocusProvider>();
              if (provider.strictMode) {
                _disableStrictMode(context);
              }
              await provider.stopFocus();
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('结束专注？'),
        content: Text('本次已专注 ${_formatDuration(provider.elapsedSeconds)}，确定要结束吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 先关闭对话框，再用页面 context 返回
              Navigator.pop(dialogContext);
              // 结束计时时自动关闭严格模式（若已开启）
              if (provider.strictMode) {
                _disableStrictMode(context);
              }
              await provider.stopFocus();
              if (mounted) {
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
    // 捕获完成时的时长与关联习惯，避免 _onFocusComplete 自动重置后 elapsedSeconds 归零
    final completedDuration = provider.lastCompletedDuration;
    final linkedHabit = provider.linkedHabit;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
              '本次专注 ${_formatDuration(completedDuration)}',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            if (linkedHabit != null) ...[
              const SizedBox(height: 8),
              Text(
                '可自动完成「${linkedHabit.name}」打卡',
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
              // 先关闭对话框
              Navigator.pop(dialogContext);

              // 自动打卡：使用捕获的完成时长，避免归零
              if (linkedHabit != null) {
                final checkInProvider = context.read<CheckInProvider>();
                await checkInProvider.checkIn(
                  linkedHabit.id,
                  DateTime.now(),
                  null,
                  null,
                  completedDuration ~/ 60,
                );
              }

              // 停止完成提示音（_completionPlayer 同时用于试听和完成提示音）
              await AudioService().stopPreview();

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

  /// 格式化时长（x小时x分x秒 / x分x秒）
  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final secs = seconds % 60;
      if (secs > 0) {
        return '$hours 小时 $minutes 分 $secs 秒';
      }
      return '$hours 小时 $minutes 分';
    } else {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      if (minutes > 0) {
        return '$minutes 分 $secs 秒';
      }
      return '$secs 秒';
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

/// 白名单应用磁贴（图标 + 名称）
///
/// 用于 FocusTimerPage 白名单悬浮面板中的网格项，点击通过 MethodChannel 启动应用。
class _WhitelistAppTile extends StatelessWidget {
  const _WhitelistAppTile({required this.app, required this.onTap});

  final WhitelistApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 应用图标（异步加载并缓存）
          _TimerPageAppIcon(packageName: app.packageName),
          const SizedBox(height: 6),
          Text(
            app.label,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 专注计时页专用的应用图标组件
///
/// 通过 MethodChannel 异步从 Android 原生层获取应用图标 Base64 并解码显示。
/// 与 FocusModeSelectPage 中的 _AppIcon 实现独立，缓存共享进程内 Map。
class _TimerPageAppIcon extends StatelessWidget {
  const _TimerPageAppIcon({required this.packageName});

  final String packageName;

  /// 进程内图标缓存：packageName → 已解码字节
  static final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  @override
  Widget build(BuildContext context) {
    final cached = _cache[packageName];
    if (cached != null) {
      return Image.memory(cached, width: 44, height: 44, gaplessPlayback: true);
    }
    return FutureBuilder<Uint8List?>(
      future: _loadIcon(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.apps,
              size: 36,
              color: AppColors.textHint,
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.android,
              size: 36,
              color: AppColors.textHint,
            ),
          );
        }
        return Image.memory(bytes, width: 44, height: 44, gaplessPlayback: true);
      },
    );
  }

  /// 通过 MethodChannel 获取应用图标并解码
  Future<Uint8List?> _loadIcon() async {
    if (_cache.containsKey(packageName)) return _cache[packageName];
    try {
      final result = await _FocusTimerPageState._appsChannel
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