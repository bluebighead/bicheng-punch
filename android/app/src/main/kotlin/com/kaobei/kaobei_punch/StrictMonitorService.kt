package com.kaobei.kaobei_punch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/// 严格模式监控 Service
///
/// 职责：
/// 1. 以前台 Service 形式常驻，显示严格模式运行通知
/// 2. 静态共享白名单包名集合和运行状态给辅助服务
/// 3. 轮询检测前台应用，若为桌面/非白名单应用则显示悬浮窗覆盖
///
/// 防切换机制（MIUI 适配方案）：
/// - 辅助服务（StrictModeAccessibilityService）监听窗口切换事件
///   - 对非桌面应用执行 GLOBAL_ACTION_BACK 拉回
/// - 本 Service 轮询检测前台应用
///   - 检测到桌面/非白名单应用时显示悬浮窗覆盖（拦截所有触摸）
///   - 悬浮窗中央放置"返回专注"按钮，点击拉回本应用
///   - 通知栏同时显示高优先级通知，点击也可拉回本应用
class StrictMonitorService : Service() {

    companion object {
        private const val CHANNEL_ID = "strict_monitor_channel"
        private const val NOTIFICATION_ID = 2001
        private const val TAG = "StrictMonitorService"
        /// 轮询间隔（毫秒）
        private const val POLL_INTERVAL_MS = 1000L

        /// 严格模式是否正在运行（供辅助服务读取）
        @Volatile
        @JvmStatic
        var isRunning: Boolean = false
            private set

        /// 白名单包名集合（供辅助服务读取）
        @Volatile
        @JvmStatic
        var whitelistPackages: Set<String> = emptySet()
            private set

        /// 启动监控
        fun start(context: Context, whitelist: Set<String>) {
            val intent = Intent(context, StrictMonitorService::class.java)
            intent.putExtra("whitelist", whitelist.toTypedArray())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /// 停止监控
        fun stop(context: Context) {
            val intent = Intent(context, StrictMonitorService::class.java)
            context.stopService(intent)
        }
    }

    /// 轮询 Handler
    private val handler = Handler(Looper.getMainLooper())
    /// 窗口管理器
    private lateinit var windowManager: WindowManager
    /// 悬浮窗视图
    private var overlayView: View? = null
    /// 悬浮窗是否正在显示
    private var isOverlayShowing = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 解析白名单包名
        val whitelistArray = intent?.getStringArrayExtra("whitelist") ?: arrayOf()
        whitelistPackages = whitelistArray.toSet()
        isRunning = true

        // 启动为前台 Service
        startForeground(NOTIFICATION_ID, buildNotification())

        // 开始轮询检测
        startPolling()

        Log.d(TAG, "严格模式监控已启动，白名单: $whitelistPackages")
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        whitelistPackages = emptySet()
        stopPolling()
        removeOverlay()
        Log.d(TAG, "严格模式监控已停止")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /// 开始轮询检测前台应用
    private fun startPolling() {
        handler.postDelayed(object : Runnable {
            override fun run() {
                checkForegroundApp()
                handler.postDelayed(this, POLL_INTERVAL_MS)
            }
        }, POLL_INTERVAL_MS)
    }

    /// 停止轮询
    private fun stopPolling() {
        handler.removeCallbacksAndMessages(null)
    }

    /// 检查前台应用，若为桌面/非白名单应用则显示悬浮窗
    ///
    /// 策略：
    /// 1. 获取前台应用包名
    /// 2. 本应用 → 移除悬浮窗
    /// 3. 白名单应用 → 移除悬浮窗
    /// 4. 其他（含桌面）→ 显示悬浮窗
    private fun checkForegroundApp() {
        val foregroundPkg = getForegroundPackage() ?: return

        // 本应用自身 → 移除悬浮窗
        if (foregroundPkg == packageName) {
            if (isOverlayShowing) {
                removeOverlay()
                Log.d(TAG, "已回到本应用，移除悬浮窗")
            }
            return
        }

        // 白名单应用 → 移除悬浮窗
        if (whitelistPackages.contains(foregroundPkg)) {
            if (isOverlayShowing) {
                removeOverlay()
                Log.d(TAG, "白名单应用 $foregroundPkg，移除悬浮窗")
            }
            return
        }

        // 非白名单应用（含桌面）→ 显示悬浮窗
        if (!isOverlayShowing) {
            Log.d(TAG, "检测到非白名单应用 $foregroundPkg，显示悬浮窗")
            showOverlay()
        }
    }

    /// 获取前台应用包名（通过 UsageStatsManager 事件查询）
    ///
    /// 使用 queryEvents 查询 MOVE_TO_FOREGROUND 事件，
    /// 比 queryUsageStats 的 lastTimeUsed 更准确
    /// （后者会被后台触发的 Activity 事件污染，导致误判）。
    private fun getForegroundPackage(): String? {
        return try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val events = usageStatsManager.queryEvents(now - 10000, now)
            val event = android.app.usage.UsageEvents.Event()
            var foregroundPkg: String? = null
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    foregroundPkg = event.packageName
                }
            }
            foregroundPkg
        } catch (e: Exception) {
            Log.e(TAG, "获取前台应用失败: ${e.message}")
            null
        }
    }

    /// 显示全屏悬浮窗覆盖非白名单应用
    ///
    /// 关键设计（避免 MIUI 问题）：
    /// 1. 拦截所有触摸（不设置 FLAG_NOT_TOUCHABLE），防止用户操作桌面
    /// 2. 在悬浮窗中央放置"返回专注"按钮，点击拉回本应用
    /// 3. 这是唯一返回入口（MIUI 后台 startActivity 被拦截）
    private fun showOverlay() {
        if (isOverlayShowing) return

        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "无悬浮窗权限")
            return
        }

        try {
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.OPAQUE
            )
            params.gravity = Gravity.CENTER

            // 创建悬浮窗视图
            val overlay = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(0xF0222222.toInt())
                setPadding(48, 48, 48, 48)
                isClickable = true
                isFocusable = true
            }

            // 提示文字
            val textView = TextView(this).apply {
                text = "专注模式运行中\n\n检测到你离开了应用\n\n请点击下方按钮返回专注"
                setTextColor(0xFFFFFFFF.toInt())
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 48)
            }
            overlay.addView(textView)

            // 返回专注按钮
            val btnReturn = android.widget.Button(this).apply {
                text = "返回专注"
                setBackgroundColor(0xFFFF6B35.toInt())
                setTextColor(0xFFFFFFFF.toInt())
                textSize = 18f
                setPadding(64, 32, 64, 32)
                setOnClickListener {
                    Log.d(TAG, "用户点击返回专注按钮")
                    returnToApp()
                }
            }
            // 设置按钮布局参数
            val btnParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            overlay.addView(btnReturn, btnParams)

            windowManager.addView(overlay, params)
            overlayView = overlay
            isOverlayShowing = true
            Log.d(TAG, "悬浮窗已显示")
        } catch (e: Exception) {
            Log.e(TAG, "显示悬浮窗失败: ${e.message}")
        }
    }

    /// 拉回本应用
    private fun returnToApp() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
                putExtra("return_to_focus_timer", true)
            }
            startActivity(intent)
            // 稍后移除悬浮窗（等待 Activity 切换完成）
            handler.postDelayed({
                removeOverlay()
            }, 300)
        } catch (e: Exception) {
            Log.e(TAG, "拉回本应用失败: ${e.message}")
        }
    }

    /// 移除悬浮窗
    private fun removeOverlay() {
        if (!isOverlayShowing || overlayView == null) return
        try {
            windowManager.removeView(overlayView)
        } catch (e: Exception) {
            Log.e(TAG, "移除悬浮窗失败: ${e.message}")
        } finally {
            overlayView = null
            isOverlayShowing = false
        }
    }

    /// 创建通知渠道
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "严格模式监控",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "专注严格模式运行中，防止用户切换应用"
                setShowBadge(true)
                enableLights(true)
                enableVibration(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    /// 构建前台 Service 通知
    ///
    /// 使用高优先级 + 横幅通知确保在 MIUI 上可见。
    /// 点击通知拉回 MainActivity（倒计时页）。
    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra("return_to_focus_timer", true)
        }
        val pendingIntent = android.app.PendingIntent.getActivity(
            this, 0, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                android.app.PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("专注进行中")
            .setContentText("严格模式已开启，点击返回专注计时")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .build()
    }
}
