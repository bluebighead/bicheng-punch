package com.kaobei.kaobei_punch

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts

class MainActivity : FlutterFragmentActivity() {
    private val STRICT_MODE_CHANNEL = "com.kaobei.kaobei_punch/strict_mode"
    private val RINGTONE_CHANNEL = "com.kaobei.kaobei_punch/ringtone"
    private val APPS_CHANNEL = "com.kaobei.kaobei_punch/apps"
    private var pendingRingtoneResult: MethodChannel.Result? = null

    // 修复问题4：改用 ActivityResultLauncher 替代 startActivityForResult。
    // 原 FlutterActivity + startActivityForResult 在某些设备/Flutter 版本下，
    // 文件选择器会立即收到 RESULT_CANCELED 导致"弹出即关闭"。
    // FlutterFragmentActivity 继承 FragmentActivity → ComponentActivity，
    // 支持 registerForActivityResult，生命周期管理更可靠。
    private val pickAudioLauncher: ActivityResultLauncher<Array<String>> =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            if (uri != null) {
                try {
                    // 将选中的音频文件复制到应用缓存目录，并返回路径 + 文件名
                    val cachedFile = copyToCache(uri)
                    val fileName = cachedFile.name
                    // 返回 Map：path = 缓存路径，name = 文件名（供 UI 显示）
                    pendingRingtoneResult?.success(
                        mapOf("path" to cachedFile.absolutePath, "name" to fileName)
                    )
                } catch (e: Exception) {
                    android.util.Log.e("RingtonePicker", "复制音频文件失败: ${e.message}")
                    pendingRingtoneResult?.success(null)
                }
            } else {
                // 用户取消选择
                pendingRingtoneResult?.success(null)
            }
            pendingRingtoneResult = null
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== 应用管理 MethodChannel（白名单功能）=====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchableApps" -> {
                    // 优化：在后台线程执行，避免主线程阻塞导致点击按钮无反应
                    // Flutter 侧已实现加载动画（CircularProgressIndicator）
                    Thread {
                        val apps = getLaunchableApps()
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.success(null)
                    } else {
                        result.success(getAppIconBase64(packageName))
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName == null) {
                        result.success(false)
                    } else {
                        result.success(launchApp(packageName))
                    }
                }
                "hasUsageAccess" -> {
                    result.success(hasUsageAccess())
                }
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 严格模式 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STRICT_MODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableStrictMode" -> {
                    // 读取白名单参数（来自 FocusProvider）
                    val whitelistArg = call.argument<List<String>>("whitelist") ?: emptyList()
                    val whitelistSet = whitelistArg.toSet()
                    enableStrictMode(whitelistSet)
                    result.success(true)
                }
                "disableStrictMode" -> {
                    disableStrictMode()
                    result.success(true)
                }
                // 检查严格模式所需权限（辅助功能 + 悬浮窗）
                "hasOverlayPermission" -> {
                    result.success(hasAccessibilityPermission())
                }
                // 请求权限：跳转系统无障碍设置页（用户还需手动授予悬浮窗权限）
                "openOverlaySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 自定义铃声选取 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    pendingRingtoneResult = result
                    // 使用 ActivityResultLauncher 启动文件选择器
                    try {
                        pickAudioLauncher.launch(arrayOf("audio/*"))
                    } catch (e: Exception) {
                        android.util.Log.e("RingtonePicker", "启动文件选择器失败: ${e.message}")
                        pendingRingtoneResult?.success(null)
                        pendingRingtoneResult = null
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /// 将 URI 指向的音频文件复制到应用缓存目录
    private fun copyToCache(uri: Uri): File {
        val cursor = contentResolver.query(uri, null, null, null, null)
        var fileName = "custom_ringtone.mp3"
        cursor?.use { c ->
            if (c.moveToFirst()) {
                val nameIndex = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    fileName = c.getString(nameIndex) ?: "custom_ringtone.mp3"
                }
            }
        }

        // 确保缓存目录存在
        val cacheDir = File(cacheDir, "ringtones")
        cacheDir.mkdirs()

        // 写入缓存文件，同名则覆盖
        val cachedFile = File(cacheDir, fileName)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(cachedFile).use { output ->
                input.copyTo(output)
            }
        }

        android.util.Log.d("RingtonePicker", "铃声已缓存到: ${cachedFile.absolutePath}")
        return cachedFile
    }

    // ===== 严格模式方法 =====

    /// 启用严格模式：全屏沉浸 + StrictMonitorService 轮询拉回非白名单应用
    /// [whitelist] 白名单包名集合，允许用户在严格模式下使用的应用
    ///
    /// 修复问题2：移除 startLockTask() 屏幕固定模式。
    /// 原实现调用 startLockTask() 进入 Android 屏幕固定（Screen Pinning）模式，
    /// 该模式会完全锁定到当前应用，白名单应用也无法打开，且提示
    /// "如需取消固定此应用，请从底端向上滑动并停顿"。
    /// 现改为仅依赖 StrictMonitorService 每 1.5 秒轮询前台应用，
    /// 非白名单应用被拉回，白名单应用可正常使用。
    private fun enableStrictMode(whitelist: Set<String>) {
        runOnUiThread {
            try {
                // 1. 设置窗口 FLAG：保持屏幕常亮 + 锁屏时显示 + 点亮屏幕
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )

                // 2. 隐藏系统导航栏和状态栏（全屏沉浸）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                    window.decorView.systemUiVisibility = (
                        android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                        android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                        android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    )
                }

                // 3. 启动 StrictMonitorService 监控前台应用并拉回非白名单应用
                StrictMonitorService.start(this, whitelist)
            } catch (e: Exception) {
                android.util.Log.e("StrictMode", "启用严格模式失败: ${e.message}")
            }
        }
    }

    /// 禁用严格模式：停止监控、恢复系统导航
    private fun disableStrictMode() {
        runOnUiThread {
            try {
                // 1. 停止 StrictMonitorService 监控
                StrictMonitorService.stop(this)

                // 2. 移除窗口 FLAG
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )

                // 3. 恢复系统导航栏和状态栏
                window.decorView.systemUiVisibility = (
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
            } catch (e: Exception) {
                android.util.Log.e("StrictMode", "禁用严格模式失败: ${e.message}")
            }
        }
    }

    // ===== 白名单应用相关方法 =====

    /// 获取所有可启动应用（有 Launcher Intent 的应用）
    ///
    /// 返回 List<Map<String, String>>，每项含 packageName 与 label
    ///
    /// 优化：原在主线程同步执行 queryIntentActivities + loadLabel 遍历所有应用，
    /// 应用数量多时（几十到上百个）会阻塞主线程导致"点击无反应"。
    /// 现改为在后台线程执行，主线程立即返回，配合 Flutter 侧加载动画。
    private fun getLaunchableApps(): List<Map<String, String>> {
        val apps = mutableListOf<Map<String, String>>()
        try {
            val pm = packageManager
            val intent = android.content.Intent(android.content.Intent.ACTION_MAIN, null)
            intent.addCategory(android.content.Intent.CATEGORY_LAUNCHER)
            // 注意：queryIntentActivities 在 Android 11+ 需配合 <queries> 声明
            val resolveInfos = pm.queryIntentActivities(intent, 0)

            // 排除本应用自身
            val myPackage = packageName
            for (info in resolveInfos) {
                val pkg = info.activityInfo.packageName
                if (pkg == myPackage) continue
                val label = info.loadLabel(pm).toString()
                apps.add(mapOf("packageName" to pkg, "label" to label))
            }

            // 按应用名称排序，便于用户查找
            apps.sortBy { it["label"] }
        } catch (e: Exception) {
            android.util.Log.e("AppsChannel", "获取应用列表失败: ${e.message}")
        }
        return apps
    }

    /// 获取应用图标的 Base64 字符串（PNG）
    ///
    /// Flutter 侧通过 Image.memory 显示。
    private fun getAppIconBase64(packageName: String): String? {
        return try {
            val pm = packageManager
            val drawable: Drawable? = pm.getApplicationIcon(packageName)
            if (drawable == null) return null

            // Drawable → Bitmap → PNG bytes → Base64
            val bitmap: Bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val width = if (drawable.intrinsicWidth <= 0) 96 else drawable.intrinsicWidth
                    val height = if (drawable.intrinsicHeight <= 0) 96 else drawable.intrinsicHeight
                    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }

            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val bytes = outputStream.toByteArray()
            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            android.util.Log.e("AppsChannel", "获取应用图标失败: ${e.message}")
            null
        }
    }

    /// 启动指定包名的应用
    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                false
            } else {
                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            }
        } catch (e: Exception) {
            android.util.Log.e("AppsChannel", "启动应用失败: ${e.message}")
            false
        }
    }

    /// 检测是否已授予「使用情况访问」权限
    private fun hasUsageAccess(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            android.util.Log.e("AppsChannel", "检测使用情况权限失败: ${e.message}")
            false
        }
    }

    /// 打开系统「使用情况访问」设置页
    private fun openUsageAccessSettings() {
        try {
            val intent = android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("AppsChannel", "打开使用情况设置失败: ${e.message}")
        }
    }

    /// 检查严格模式所需权限是否已授予
    ///
    /// 严格模式需要两项权限：
    /// 1. 辅助功能权限（StrictModeAccessibilityService）：
    ///    监听窗口切换事件，对非桌面应用执行 BACK 拉回
    /// 2. 悬浮窗权限（SYSTEM_ALERT_WINDOW）：
    ///    检测到桌面/非白名单应用时显示覆盖层（因 BACK 对桌面无效）
    ///
    /// 注意：方法名保留 hasOverlayPermission 以避免 Flutter 侧改动过大，
    /// 实际同时检查辅助功能权限和悬浮窗权限。
    private fun hasAccessibilityPermission(): Boolean {
        // 1. 检查辅助功能权限
        val enabledServices = android.provider.Settings.Secure.getString(
            contentResolver,
            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val serviceName = "$packageName/${StrictModeAccessibilityService::class.java.name}"
        val hasAccessibility = enabledServices.contains(serviceName)

        // 2. 检查悬浮窗权限
        val hasOverlay = android.provider.Settings.canDrawOverlays(this)

        android.util.Log.d("StrictMode", "权限检查: 辅助功能=$hasAccessibility, 悬浮窗=$hasOverlay")
        return hasAccessibility && hasOverlay
    }

    /// 打开系统无障碍设置页
    ///
    /// 引导用户找到「笔程」并开启严格模式辅助服务。
    /// 用户开启辅助服务后，还需手动授予悬浮窗权限。
    private fun openAccessibilitySettings() {
        try {
            val intent = android.content.Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            // 提示用户还需授予悬浮窗权限
            android.widget.Toast.makeText(
                this,
                "开启辅助服务后，请同时授予悬浮窗权限",
                android.widget.Toast.LENGTH_LONG
            ).show()
        } catch (e: Exception) {
            android.util.Log.e("StrictMode", "打开无障碍设置失败: ${e.message}")
        }
    }
}
