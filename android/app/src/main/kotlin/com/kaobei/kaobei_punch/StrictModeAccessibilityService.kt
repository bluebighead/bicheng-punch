package com.kaobei.kaobei_punch

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/// 严格模式辅助服务
///
/// 职责：
/// 监听系统窗口切换事件（TYPE_WINDOW_STATE_CHANGED），检测前台应用切换。
/// 当检测到切换到非白名单应用时执行 GLOBAL_ACTION_BACK 拉回。
///
/// 重要说明（MIUI 限制）：
/// - MIUI 静默拦截后台 startActivity，无法自动拉回本应用
/// - GLOBAL_ACTION_BACK 对桌面无效
/// - GLOBAL_ACTION_RECENTS 会触发循环（最近任务界面包名是 com.miui.home）
/// - 因此桌面场景由 StrictMonitorService 的悬浮窗处理，辅助服务只处理非桌面应用
///
/// 工作流程：
/// 1. 检测到非白名单应用切换
/// 2. 非桌面应用 → 执行 GLOBAL_ACTION_BACK 拉回
/// 3. 桌面/系统 UI → 仅记录日志，由 StrictMonitorService 轮询检测并显示悬浮窗
class StrictModeAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "StrictAccessibility"
        /// 拉回动作最小间隔（毫秒），避免短时间内多次拉回导致事件风暴
        private const val PULLBACK_INTERVAL_MS = 1000L
        /// 桌面包名（MIUI）
        private const val MIUI_HOME_PKG = "com.miui.home"
        /// 系统 UI 包名
        private const val SYSTEM_UI_PKG = "com.android.systemui"
        /// MIUI 系统插件包名（控制中心等）
        private const val MIUI_PLUGIN_PKG = "miui.systemui.plugin"
    }

    /// 上次执行拉回动作的时间戳，用于限流
    private var lastPullbackTime = 0L

    /// 辅助服务连接时回调
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "辅助服务已连接")
    }

    /// 辅助服务中断时回调
    override fun onInterrupt() {
        Log.w(TAG, "辅助服务被中断")
    }

    /// 处理无障碍事件（核心逻辑）
    ///
    /// 监听 TYPE_WINDOW_STATE_CHANGED 事件，检测前台应用切换。
    /// 仅对非桌面应用执行 BACK（对桌面无效且会循环）。
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        // 严格模式未运行时不处理
        if (!StrictMonitorService.isRunning) return

        // 获取触发事件的包名
        val pkg = event.packageName?.toString() ?: return
        if (pkg.isEmpty()) return

        // 本应用自身 → 不处理
        if (pkg == packageName) return

        // 白名单应用 → 允许使用
        if (StrictMonitorService.whitelistPackages.contains(pkg)) return

        // 限流
        val now = System.currentTimeMillis()
        if (now - lastPullbackTime < PULLBACK_INTERVAL_MS) return
        lastPullbackTime = now

        // 判断是否为桌面/系统UI场景
        val isHomeScenario = pkg == MIUI_HOME_PKG ||
            pkg == SYSTEM_UI_PKG ||
            pkg == MIUI_PLUGIN_PKG ||
            pkg.contains("home") ||
            pkg.contains("launcher")

        if (isHomeScenario) {
            // 桌面场景：BACK 无效，只记录日志，不执行动作（避免循环）
            // 悬浮窗由 StrictMonitorService 的轮询机制处理
            Log.d(TAG, "检测到桌面/系统UI: $pkg（BACK 无效，等待悬浮窗处理）")
        } else {
            // 非桌面场景：执行 BACK 拉回
            val backSuccess = performGlobalAction(GLOBAL_ACTION_BACK)
            Log.d(TAG, "检测到非白名单应用: $pkg，BACK 执行结果: $backSuccess")
        }
    }
}
