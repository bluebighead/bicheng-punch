# 批量删除 / 白名单应用 / 铃声修复 设计文档

> **创建日期：** 2026-06-27
> **范围：** 今日打卡页批量操作 + 专注白名单应用（设置 + 倒计时弹层 + 强制返回）+ 倒计时结束铃声不播放修复

---

## 一、需求概述

### 功能 1：今日打卡页批量操作
在「今日待打卡」标题右侧加入批量操作按钮，进入批量操作界面后可：
- 单选/多选习惯卡片
- 一键全选/取消全选
- 批量删除选中项（带二次确认）

### 功能 2：开始专注设置页白名单设置
在 `focus_mode_select_page` 新增白名单应用设置区块：
- 用户可自定义添加白名单应用
- 最多 3 个
- 严格模式下仅允许使用白名单内应用

### 功能 3：倒计时页白名单弹层 + 强制返回
- 倒计时页菜单栏新增「白名单」项
- 点击弹出应用内弹层，列出已添加的白名单应用图标
- 点击图标启动对应应用
- 严格模式开启时，前台 Service 监控前台应用：
  - 前台应用 ∈ {本应用 + 白名单} → 允许
  - 前台应用为其他 → 自动拉回倒计时界面
- 用户尝试返回桌面 / 切换应用 / 找 bug 逃离均无效，都会被拉回
- 直到倒计时结束或解除严格模式才能离开

### 功能 4：倒计时结束铃声不播放修复
修复倒计时结束后未播放设置铃声的问题。

---

## 二、架构与数据流

### 2.1 功能 1（批量操作）— 纯 Flutter 层

```
HomePage (StatefulWidget)
  ├─ _batchMode: bool              // 是否处于批量模式
  ├─ _selectedIds: Set<String>     // 选中的习惯 ID
  └─ 顶部批量操作条 + 习惯卡片复选框
        ↓ 批量删除
  HabitProvider.removeHabit(id) × N
  CheckInProvider.cancelCheckIn(id) × N（清理对应打卡记录）
```

**关键约束：**
- 批量模式下禁用：左滑删除（Dismissible）、打卡点击
- 选中数=0 时禁用「删除」按钮，仅显示「退出」
- 全选/取消全选以当前 `todayHabits` 为基准（不含已完成项也可选，便于清理）

### 2.2 功能 2（白名单设置）— Flutter + 原生 MethodChannel

```
focus_mode_select_page
  └─ 白名单设置区块
        ├─ 已添加应用列表（图标 + 名称 + 删除按钮）
        └─ 「+ 添加」按钮（满 3 个时禁用）
              ↓ 点击
        MethodChannel('com.kaobei.kaobei_punch/apps')
          method='getLaunchableApps'  → List<{packageName, label, iconBytes?}>
        ↓ 弹出选择器（搜索框 + 列表）
        ↓ 选中后存入
  StorageService.configBox['whitelist_apps'] = JSON
```

**数据模型（`lib/models/whitelist_app_model.dart`）：**
```dart
class WhitelistApp {
  final String packageName;
  final String label;
  // icon 不持久化，按需通过原生获取，避免 Hive 体积膨胀
}
```

**存储格式：** `config_box` 的 `whitelist_apps` key，值为 `List<Map>` JSON 字符串。
**上限：** 3 个，UI 层硬约束。

### 2.3 功能 3（弹层 + 强制返回）— Flutter + 原生前台 Service

```
focus_timer_page 菜单
  └─ 「白名单」项（仅 countdown 模式显示）
        ↓ 点击
  应用内底部弹层（白名单应用图标网格）
        ↓ 点击图标
  MethodChannel('com.kaobei.kaobei_punch/apps')
    method='launchApp' args={packageName}

严格模式开启 →
  MethodChannel('com.kaobei.kaobei_punch/strict_mode')
    method='enableStrictMode' args={whitelist: [...], countdownRunning: true}
        ↓
  StrictMonitorService 启动（前台 Service + 通知）
    每 1.5s 查询 UsageStatsManager.queryUsageStats
    if 前台包名 ∉ {本应用 + 白名单}:
      Intent 启动 MainActivity → Flutter 路由到 focus_timer_page

严格模式关闭 / 倒计时结束 →
  method='disableStrictMode'
        ↓
  StrictMonitorService 停止
```

**权限引导：**
- 首次开启严格模式时，通过 `AppOpsManager.checkOpNoThrow(OPSTR_GET_USAGE_STATS)` 检测
- 未授权 → 弹窗引导跳转 `Settings.ACTION_USAGE_ACCESS_SETTINGS`
- 用户返回后再次检测，仍未授权则严格模式不生效并提示

### 2.4 功能 4（铃声修复）— 纯逻辑修复

**根因：** `FocusProvider._onFocusComplete()` 流程为：
```
1. 设置 timerState = completed
2. stopPreview()（停止试听，OK）
3. playCompletionSound(...)（播放完成铃声，OK）
4. await Future.delayed(500ms)
5. _resetState()  ← 问题在这
```

`_resetState()` 中存在两行：
```dart
await _stopPreviewIfNeeded();  // OK，仅当试听状态时停止
await _audioService?.stopPreview();  // ← BUG：无条件停止，掐断刚响起的完成铃声
if (_isPreviewPlaying) { _isPreviewPlaying = false; }
```

**修复：** 移除 `_resetState()` 中无条件的 `await _audioService?.stopPreview();`，仅保留 `_stopPreviewIfNeeded()`。完成铃声在用户点击完成对话框「好的」按钮时由 `AudioService().stopPreview()` 停止。

---

## 三、组件设计

### 3.1 功能 1 组件

| 组件 | 位置 | 职责 |
|------|------|------|
| `HomePage._batchMode` | State 字段 | 批量模式开关 |
| `HomePage._selectedIds` | State 字段 | 选中集合 |
| `HomePage._buildBatchTopBar()` | 新增方法 | 批量模式顶部条（全选/取消/删除/退出） |
| `HabitCard.batchMode` | 新增参数 | 控制是否显示复选框 + 是否禁用打卡点击 |
| `HabitCard.isSelected` | 新增参数 | 复选框选中状态 |
| `HabitCard.onSelectToggle` | 新增回调 | 复选框点击 |

### 3.2 功能 2 组件

| 组件 | 位置 | 职责 |
|------|------|------|
| `WhitelistApp` | `lib/models/whitelist_app_model.dart` | 数据类 |
| `StorageService.getWhitelistApps()` | 新增静态方法 | 读取白名单 |
| `StorageService.setWhitelistApps(list)` | 新增静态方法 | 写入白名单 |
| `FocusProvider.whitelistApps` | 新增字段 + getter | 内存态白名单（与持久化同步） |
| `FocusProvider.addWhitelistApp(app)` | 新增方法 | 添加（受 3 个上限约束） |
| `FocusProvider.removeWhitelistApp(packageName)` | 新增方法 | 删除 |
| `_buildWhitelistSelector()` | `focus_mode_select_page` 新增方法 | 白名单设置 UI |
| `_showAppPickerDialog()` | `focus_mode_select_page` 新增方法 | 应用选择器弹窗 |

### 3.3 功能 3 组件

| 组件 | 位置 | 职责 |
|------|------|------|
| `_buildMenuButton` 新增菜单项 | `focus_timer_page` | 「白名单」入口 |
| `_showWhitelistBottomSheet()` | `focus_timer_page` 新增方法 | 应用内白名单弹层 |
| `StrictMonitorService` | `android/.../StrictMonitorService.kt` 新增 | 前台 Service 轮询拉回 |
| MethodChannel `apps` | `MainActivity.kt` 扩展 | getLaunchableApps / launchApp / getAppIcon / hasUsageAccess / openUsageAccessSettings |

### 3.4 功能 4 组件

仅修改 `FocusProvider._resetState()`，无新增组件。

---

## 四、错误处理与边界

### 功能 1
- 批量模式下数据刷新（添加习惯后）：保留仍在列表中的选中项，丢失的项静默忽略
- 删除过程中 Provider 通知刷新，`_selectedIds` 同步清理已删除 ID
- 空列表时批量按钮隐藏（与现有 `if (todayHabits.isNotEmpty)` 一致）

### 功能 2
- 原生获取应用列表失败 → 弹窗提示 + 返回空列表
- 同一 packageName 重复添加 → 提示已存在
- 持久化失败 → debugPrint，不阻塞 UI

### 功能 3
- 白名单为空时弹层显示空状态提示「请先在开始专注设置中添加白名单应用」
- 启动应用失败（包名无效）→ SnackBar 提示
- 用户未授予使用情况权限 → 严格模式开关置回 false + 弹窗引导
- StrictMonitorService 在 onDestroy 中安全清理 Handler 回调，避免内存泄漏
- 倒计时结束 / 严格模式关闭 → 立即停止 Service

### 功能 4
- 试听状态与完成铃声共用 `_completionPlayer`，修复后仅在试听态停止，完成铃声不被打断
- 完成对话框「好的」按钮调用 `stopPreview()` 兜底停止

---

## 五、测试要点

| 功能 | 测试点 |
|------|--------|
| 1 | 批量选中/全选/取消全选；批量删除后列表与计数刷新；批量模式下打卡与左滑禁用 |
| 2 | 添加白名单应用上限 3 个；重复添加提示；删除后可再加；持久化跨重启 |
| 3 | 严格模式下切到非白名单应用被拉回；切到白名单应用可正常使用；返回桌面被拉回；解除严格模式后可自由切换；倒计时结束自动停止监控 |
| 4 | 倒计时结束后铃声正常播放；完成对话框「好的」按钮停止铃声；试听功能不受影响 |

---

## 六、文件清单

### 新增文件
- `lib/models/whitelist_app_model.dart` — 白名单应用数据类
- `android/app/src/main/kotlin/com/kaobei/kaobei_punch/StrictMonitorService.kt` — 前台监控 Service

### 修改文件
| 文件 | 改动摘要 |
|------|----------|
| `lib/pages/home/home_page.dart` | 功能 1 批量操作 UI |
| `lib/widgets/habit_card.dart` | 新增 batchMode/isSelected/onSelectToggle 参数 |
| `lib/pages/focus/focus_mode_select_page.dart` | 功能 2 白名单设置区块 |
| `lib/providers/focus_provider.dart` | 白名单状态管理 + 功能 4 铃声修复 |
| `lib/pages/focus/focus_timer_page.dart` | 功能 3 菜单白名单项 + 弹层 + 严格模式权限引导 |
| `lib/services/storage_service.dart` | 白名单读写便捷方法 |
| `android/app/src/main/kotlin/com/kaobei/kaobei_punch/MainActivity.kt` | apps MethodChannel |
| `android/app/src/main/AndroidManifest.xml` | 注册 Service + queries + 权限声明 |

---

## 七、技术约束与回退

- **Flutter 3.x + Provider + Material 3**，不引入新第三方依赖
- **Hive 持久化**（复用 `config_box`）
- **Android 原生**：Kotlin + MethodChannel + Foreground Service
- **不破坏现有数据**：白名单使用新 key，不影响 `_focusRecords` / `_habits`
- **回退策略**：原生权限未授予时，严格模式降级为仅沉浸模式（现有行为），白名单弹层仍可用但无强制返回能力
