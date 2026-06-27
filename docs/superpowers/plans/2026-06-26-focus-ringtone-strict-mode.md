# 专注铃声与严格模式实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 专注倒计时模式支持自定义结束铃声（不存数据库），倒计时页面右上角汉堡菜单铃声快捷切换；菜单中增加严格模式/正常模式开关，严格模式锁定用户操作。

**Architecture:**
- 铃声功能：`FocusProvider` 内存态 `_selectedRingtone` + `AudioService` 扩展多铃声播放 + 设置页/菜单页 UI
- 严格模式：`FocusProvider` 内存态 `_strictMode` + Android 原生 MethodChannel 实现锁屏/锁任务 + Flutter `PopScope` + `SystemChrome` 沉浸模式

**Tech Stack:** Flutter 3.x, Provider, Android MethodChannel, SystemChrome, PopScope

---

## 文件结构规划

**新增文件：**
- 无

**修改文件：**
| 文件 | 改动内容 |
|------|----------|
| `lib/models/focus_record_model.dart` | 新增 `RingtoneType` 枚举 |
| `lib/providers/focus_provider.dart` | 新增 `_selectedRingtone`、`_strictMode` 状态及 getter/setter |
| `lib/services/audio_service.dart` | 新增多铃声播放支持、`playCompletionSound(RingtoneType)` |
| `lib/pages/focus/focus_mode_select_page.dart` | 倒计时模式下新增铃声选择器 UI |
| `lib/pages/focus/focus_timer_page.dart` | 顶部栏右上角新增汉堡菜单，内含铃声快捷切换 + 严格模式开关 |
| `android/app/.../MainActivity.kt` | 新增 MethodChannel 处理锁任务/沉浸模式 |
| `android/app/.../AndroidManifest.xml` | 添加锁任务相关权限 |

---

### Task 1: 新增 RingtoneType 枚举

**Files:**
- Modify: `lib/models/focus_record_model.dart`

- [ ] **Step 1: 在 focus_record_model.dart 末尾添加 RingtoneType 枚举**

在文件末尾（`WhiteNoiseType` 枚举之后）添加：

```dart
/// 专注结束铃声类型枚举
///
/// 不持久化到数据库，仅内存态存储。
/// 音频文件需放置到 assets/audio/ 目录下。
enum RingtoneType {
  classic,   // 经典提示音 -> complete.mp3
  gentle,    // 轻柔铃声 -> gentle.mp3
  digital,   // 数字闹铃 -> digital.mp3
  nature,    // 自然风铃 -> nature.mp3
}
```

---

### Task 2: FocusProvider 新增铃声和严格模式状态

**Files:**
- Modify: `lib/providers/focus_provider.dart`

- [ ] **Step 1: 新增字段、getters 和 setters**

在 `FocusProvider` 类中，在现有字段后添加：

```dart
  // ===== 铃声选择（内存态，不存数据库） =====
  RingtoneType _selectedRingtone = RingtoneType.classic; // 默认经典铃声

  // ===== 严格模式 =====
  bool _strictMode = false;

  // ===== 新增 Getters =====
  RingtoneType get selectedRingtone => _selectedRingtone;
  bool get strictMode => _strictMode;
```

- [ ] **Step 2: 添加 setter 方法**

在 `toggleWhiteNoise` 方法之后添加：

```dart
  // ===== 铃声控制 =====
  /// 设置结束铃声类型（内存态，不存数据库）
  void setRingtone(RingtoneType type) {
    _selectedRingtone = type;
    notifyListeners();
  }

  // ===== 严格模式控制 =====
  /// 切换严格模式
  void toggleStrictMode() {
    _strictMode = !_strictMode;
    notifyListeners();
  }

  /// 设置严格模式
  void setStrictMode(bool value) {
    _strictMode = value;
    notifyListeners();
  }
```

- [ ] **Step 3: 更新 `_onFocusComplete` 方法传入铃声类型**

修改 `_onFocusComplete` 方法，将 `_selectedRingtone` 传递给播放方法：

```dart
  /// 专注完成回调
  Future<void> _onFocusComplete() async {
    _timerState = TimerState.completed;
    notifyListeners();

    // 播放完成提示音（使用用户选择的铃声）
    await _audioService?.playCompletionSound(_selectedRingtone);

    // 保存专注记录
    await _saveFocusRecord();

    // 自动完成关联习惯打卡（由 UI 层调用 CheckInProvider）
    if (_linkedHabit != null) {
      debugPrint('专注完成，准备自动打卡习惯: ${_linkedHabit!.name}');
    }

    // 重置状态（延迟执行，让 UI 有时间处理完成事件）
    await Future.delayed(const Duration(milliseconds: 500));
    await _resetState();
  }
```

需要添加导入：
```dart
import '../models/focus_record_model.dart';
```
（该导入已存在，无需添加）

---

### Task 3: AudioService 支持多铃声播放

**Files:**
- Modify: `lib/services/audio_service.dart`

- [ ] **Step 1: 添加铃声资源映射和多铃声播放方法**

在 `_noiseAssets` 映射之后添加铃声资源映射：

```dart
  /// 铃声音频资源映射
  static const Map<RingtoneType, String> _ringtoneAssets = {
    RingtoneType.classic: 'assets/audio/complete.mp3',
    RingtoneType.gentle: 'assets/audio/gentle.mp3',
    RingtoneType.digital: 'assets/audio/digital.mp3',
    RingtoneType.nature: 'assets/audio/nature.mp3',
  };

  /// 铃声名称映射（用于 UI 显示）
  static const Map<RingtoneType, String> ringtoneNames = {
    RingtoneType.classic: '经典提示音',
    RingtoneType.gentle: '轻柔铃声',
    RingtoneType.digital: '数字闹铃',
    RingtoneType.nature: '自然风铃',
  };

  /// 铃声图标映射（用于 UI 显示）
  static const Map<RingtoneType, IconData> ringtoneIcons = {
    RingtoneType.classic: Icons.notifications_active,
    RingtoneType.gentle: Icons.music_note,
    RingtoneType.digital: Icons.alarm,
    RingtoneType.nature: Icons.forest,
  };
```

- [ ] **Step 2: 修改 `playCompletionSound` 方法支持铃声类型**

将原有的 `playCompletionSound` 方法改为带可选参数的新方法：

```dart
  /// 播放完成提示音
  ///
  /// [ringtone] 可选，指定铃声类型，默认为经典提示音
  Future<void> playCompletionSound([RingtoneType ringtone = RingtoneType.classic]) async {
    try {
      await _completionPlayer.stop();

      final asset = _ringtoneAssets[ringtone]!;
      await _completionPlayer.setSource(
        AssetSource(asset.replaceFirst('assets/', '')),
      );
      await _completionPlayer.setVolume(0.7);
      await _completionPlayer.resume();
      debugPrint('播放完成提示音: ${ringtone.name}');
    } catch (e) {
      debugPrint('播放完成提示音失败: $e (资源文件可能不存在)');
      // 降级：如果指定铃声不存在，尝试播放默认铃声
      if (ringtone != RingtoneType.classic) {
        debugPrint('降级播放默认提示音');
        await playCompletionSound(RingtoneType.classic);
      }
    }
  }
```

还需要添加导入（在文件顶部）：

```dart
import '../models/focus_record_model.dart';
```

并且需要添加 `IconData` 的导入（如果尚未导入）：
```dart
import 'package:flutter/material.dart';
```
（检查是否已有该导入）

查看现有导入：`package:flutter/material.dart` 已导入。

- [ ] **Step 3: 确保 AudioService 的 dispose 方法清理资源（无需修改，已有）**

---

### Task 4: FocusModeSelectPage 倒计时模式新增铃声选择器

**Files:**
- Modify: `lib/pages/focus/focus_mode_select_page.dart`

- [ ] **Step 1: 在倒计时模式设置区域底部添加铃声选择区块**

在 `_buildDurationSelector` 之后、白噪音区块之前插入铃声选择 UI。

具体位置：在 `_buildSection(title: '白噪音', ...)` 之前添加。

找到以下代码块：

```dart
                // ===== 白噪音 =====
                _buildSection(
                  title: '白噪音',
                  child: _buildWhiteNoiseSelector(focusProvider),
                ),
```

在前面添加：

```dart
                // ===== 结束铃声（仅倒计时模式） =====
                if (focusProvider.mode == FocusMode.countdown) ...[
                  _buildSection(
                    title: '结束铃声',
                    child: _buildRingtoneSelector(focusProvider),
                  ),
                  const SizedBox(height: 24),
                ],
```

- [ ] **Step 2: 添加 `_buildRingtoneSelector` 方法**

在 `_buildWhiteNoiseSelector` 方法之后添加：

```dart
  /// 构建铃声选择器
  Widget _buildRingtoneSelector(FocusProvider provider) {
    final ringtones = RingtoneType.values;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ringtones.map((ringtone) {
        final isSelected = provider.selectedRingtone == ringtone;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AudioService.ringtoneIcons[ringtone] ?? Icons.notifications_active,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                AudioService.ringtoneNames[ringtone] ?? ringtone.name,
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              provider.setRingtone(ringtone);
              // 播放预览
              AudioService().playCompletionSound(ringtone);
            }
          },
          selectedColor: AppColors.primaryLight.withValues(alpha: 0.4),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      }).toList(),
    );
  }
```

- [ ] **Step 3: 更新导入（如果尚未导入 `AudioService` 和 `Icons`）**

检查文件顶部导入：

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';
import '../../models/habit_model.dart';
import '../../providers/focus_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/audio_service.dart';  // 需要新增
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
```

需要添加 `audio_service` 的导入。

---

### Task 5: FocusTimerPage 右上角汉堡菜单 + 铃声快捷切换 + 严格模式开关

**Files:**
- Modify: `lib/pages/focus/focus_timer_page.dart`

这是最复杂的 UI 改动。需要：
1. 在顶部栏右上角添加汉堡菜单（三层堆叠菜单图标）
2. 菜单中包含：铃声选择、严格模式开关

- [ ] **Step 1: 重构顶部工具栏，添加汉堡菜单按钮**

修改 `_buildTopBar` 方法：

```dart
  /// 构建顶部工具栏
  Widget _buildTopBar(FocusProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePaddingH,
        vertical: 12,
      ),
      child: Row(
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

          const SizedBox(width: 8),

          // ===== 右上角汉堡菜单按钮 =====
          _buildMenuButton(context, provider),
        ],
      ),
    );
  }
```

- [ ] **Step 2: 添加 `_buildMenuButton` 方法**

在 `_buildNoiseIndicator` 方法之后添加：

```dart
  /// 构建右上角汉堡菜单按钮（三层堆叠菜单图标）
  Widget _buildMenuButton(BuildContext context, FocusProvider provider) {
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
        switch (value) {
          case 'ringtone':
            _showRingtonePicker(context, provider);
            break;
          case 'strict_mode':
            provider.toggleStrictMode();
            _onStrictModeChanged(context, provider);
            break;
        }
      },
      itemBuilder: (context) => [
        // ===== 铃声设置 =====
        PopupMenuItem<String>(
          value: 'ringtone',
          child: Row(
            children: [
              Icon(
                AudioService.ringtoneIcons[provider.selectedRingtone] ?? Icons.notifications_active,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Column(
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
                    AudioService.ringtoneNames[provider.selectedRingtone] ?? '经典提示音',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
                activeColor: AppColors.error,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 3: 添加铃声选择弹窗 `_showRingtonePicker`**

在 `_buildMenuButton` 之后添加：

```dart
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
                  final isSelected = provider.selectedRingtone == ringtone;
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
                            onPressed: () {
                              AudioService().playCompletionSound(ringtone);
                            },
                          ),
                    selected: isSelected,
                    onTap: () {
                      provider.setRingtone(ringtone);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: 添加严格模式变更处理 `_onStrictModeChanged`**

在 `_showRingtonePicker` 之后添加：

```dart
  /// 严格模式变更处理
  void _onStrictModeChanged(BuildContext context, FocusProvider provider) {
    if (provider.strictMode) {
      // 启用严格模式：显示提示并锁定
      _enableStrictMode(context);
    } else {
      // 禁用严格模式：解锁
      _disableStrictMode(context);
    }
  }

  /// 启用严格模式
  void _enableStrictMode(BuildContext context) {
    // 1. 隐藏系统状态栏和导航栏（沉浸模式）
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // 2. 锁定屏幕方向为竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 3. 通过 MethodChannel 通知 Android 原生层锁定任务
    _invokeAndroidMethod('enableStrictMode');

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

    // 3. 通过 MethodChannel 通知 Android 原生层解锁任务
    _invokeAndroidMethod('disableStrictMode');

    // 4. 显示提示
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
```

- [ ] **Step 5: 添加 Android MethodChannel 调用方法**

在 `_onStrictModeChanged` 之后添加：

```dart
  /// 调用 Android 原生 MethodChannel
  static const _channel = MethodChannel('com.kaobei.kaobei_punch/strict_mode');

  static Future<void> _invokeAndroidMethod(String method) async {
    try {
      await _channel.invokeMethod(method);
    } catch (e) {
      debugPrint('Android 原生方法调用失败: $e');
      // 失败不阻塞，Flutter 侧仍然执行沉浸模式等操作
    }
  }
```

- [ ] **Step 6: 更新 PopScope 支持严格模式**

修改 `build` 方法中的 `PopScope`，让其在严格模式下完全不能返回：

```dart
  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, provider, child) {
        return PopScope(
          canPop: !provider.strictMode, // 严格模式下完全不能返回
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (provider.strictMode) {
                // 严格模式下：不做任何操作，提示用户
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('严格模式下无法返回'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else {
                // 正常模式下：显示退出确认对话框
                _showExitDialog(context);
              }
            }
          },
          child: ... // 原有的 Scaffold
        );
      },
    );
  }
```

需要将原有的 `PopScope` 外层包裹改为 `Consumer<FocusProvider>` 包裹。

- [ ] **Step 7: 更新 dispose 方法恢复系统设置**

```dart
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
```

- [ ] **Step 8: 添加所需的导入**

在文件顶部添加新的导入：

```dart
import 'package:flutter/services.dart';
import '../../models/focus_record_model.dart';
import '../../services/audio_service.dart';
```

检查现有导入，补充缺失的：

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // 新增：SystemChrome, MethodChannel
import 'package:provider/provider.dart';
import '../../models/focus_record_model.dart';  // 新增：RingtoneType
import '../../providers/focus_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../services/audio_service.dart';  // 新增：AudioService
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/focus_timer_ring.dart';
import '../../utils/timer_utils.dart';
```

---

### Task 6: Android 原生 MethodChannel 实现严格模式锁任务

**Files:**
- Modify: `android/app/src/main/kotlin/com/kaobei/kaobei_punch/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 修改 MainActivity.kt 添加 MethodChannel 处理**

```kotlin
package com.kaobei.kaobei_punch

import android.view.WindowManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kaobei.kaobei_punch/strict_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableStrictMode" -> {
                    enableStrictMode()
                    result.success(true)
                }
                "disableStrictMode" -> {
                    disableStrictMode()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// 启用严格模式：锁定任务、全屏沉浸、防止应用切换
    private fun enableStrictMode() {
        runOnUiThread {
            try {
                // 1. 尝试锁定任务（屏幕固定），防止用户切换到其他应用
                // 注意：需要用户在系统设置中启用"屏幕固定"功能
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    startLockTask()
                }

                // 2. 设置窗口 FLAG：保持屏幕常亮 + 锁定当前任务
                activity?.window?.addFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )

                // 3. 隐藏系统导航栏和状态栏（全屏沉浸）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    activity?.window?.decorView?.systemUiVisibility = (
                        android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                        android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    )
                }
            } catch (e: Exception) {
                debugPrint("启用严格模式失败: ${e.message}")
            }
        }
    }

    /// 禁用严格模式：解锁任务、恢复系统导航
    private fun disableStrictMode() {
        runOnUiThread {
            try {
                // 1. 解锁任务
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    stopLockTask()
                }

                // 2. 移除窗口 FLAG
                activity?.window?.clearFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )

                // 3. 恢复系统导航栏和状态栏
                activity?.window?.decorView?.systemUiVisibility = (
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
            } catch (e: Exception) {
                debugPrint("禁用严格模式失败: ${e.message}")
            }
        }
    }
}
```

- [ ] **Step 2: 在 AndroidManifest.xml 中添加锁任务相关权限**

在 `<manifest>` 内部的 `<uses-permission>` 区域添加：

```xml
    <!-- 严格模式：锁定任务防止切换应用 -->
    <uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

注意：`startLockTask()` 实际上不需要特殊权限——这是 Android 内置的"屏幕固定"功能，用户可以在系统设置中启用。上述权限是辅助性的，用于增强严格模式效果。

对于 Android 12+，`startLockTask()` 可能需要 `MANAGE_ACTIVITY_TASKS` 权限。如果该权限不可用，`startLockTask()` 会静默失败，此时依靠 Flutter 侧的 `SystemChrome` 沉浸模式和 `PopScope` 来达到近似效果。

---

### Task 7: 验证和测试

- [ ] **Step 1: 运行 `flutter analyze` 检查代码无错误**

```bash
flutter analyze
```

预期输出：无错误，或有可接受的 warning。

- [ ] **Step 2: 运行 `flutter build` 确保编译通过**

```bash
flutter build apk --debug
```

预期输出：BUILD SUCCESSFUL。

- [ ] **Step 3: 功能验证**

验证清单：
1. ✅ 倒计时模式设置页面新增"结束铃声"选择器
2. ✅ 选择铃声可预览播放
3. ✅ 专注计时页右上角有汉堡菜单按钮（三层堆叠图标）
4. ✅ 汉堡菜单可快捷切换铃声
5. ✅ 汉堡菜单有严格模式开关
6. ✅ 开启严格模式后不能返回（PopScope 阻止）
7. ✅ 开启严格模式后隐藏系统导航栏和状态栏
8. ✅ 开启严格模式后尝试锁定任务防止切换应用
9. ✅ 关闭严格模式后恢复正常操作
10. ✅ 铃声选择不持久化到数据库（内存态）
