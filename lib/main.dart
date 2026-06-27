import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_router.dart';
import 'providers/theme_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/check_in_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/login_provider.dart';
import 'services/storage_service.dart';
import 'services/audio_service.dart';
import 'services/widget_service.dart';

/// 应用入口
///
/// 初始化流程：
/// 1. 确保 WidgetsBinding 初始化
/// 2. 初始化本地存储（Hive），注册 TypeAdapter
/// 3. 注入 Provider 状态管理（主题、习惯、打卡记录）
/// 4. 启动 MaterialApp，Material 3 主题 + 命名路由
void main() async {
  // 确保绑定初始化（在调用任何平台通道前必须执行）
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务（包含 Hive 初始化和 TypeAdapter 注册）
  await StorageService.init();

  // 初始化音频服务（专注白噪音）
  await AudioService().init();

  // 初始化桌面小组件
  await WidgetService.init();

  runApp(const KaobeiPunchApp());
}

/// 应用根 Widget
class KaobeiPunchApp extends StatelessWidget {
  const KaobeiPunchApp({super.key});

  /// 设置登录同步回调：将云端数据导入到各 Provider
  void _setupSyncCallbacks(LoginProvider loginProvider, BuildContext context) {
    loginProvider.setOnHabitsReceived((habits) async {
      final habitProvider = context.read<HabitProvider>();
      await habitProvider.importFromJson(habits);
    });
    loginProvider.setOnCheckInsReceived((checkIns) async {
      final checkInProvider = context.read<CheckInProvider>();
      await checkInProvider.importFromJson(checkIns);
    });
    loginProvider.setOnSyncComplete(() {
      debugPrint('云端数据同步完成');
    });

    // 当本地习惯数据发生变更时，自动上传到服务器
    final habitProvider = context.read<HabitProvider>();
    habitProvider.onDataChanged = () {
      loginProvider.syncToServer(
        habits: habitProvider.exportToJson(),
      );
    };

    // 当本地打卡数据发生变更时，自动上传到服务器
    final checkInProvider = context.read<CheckInProvider>();
    checkInProvider.onDataChanged = () {
      loginProvider.syncToServer(
        checkIns: checkInProvider.exportToJson(),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 主题模式管理（默认跟随系统）
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        // 习惯状态管理
        ChangeNotifierProvider<HabitProvider>(
          create: (_) => HabitProvider()..loadHabits(),
        ),
        // 打卡记录状态管理
        ChangeNotifierProvider<CheckInProvider>(
          create: (_) => CheckInProvider()..loadCheckIns(),
        ),
        // 专注状态管理
        ChangeNotifierProvider<FocusProvider>(
          create: (_) => FocusProvider(),
        ),
        // 统计数据状态管理
        ChangeNotifierProvider<StatsProvider>(
          create: (_) => StatsProvider(),
        ),
        // 登录状态管理
        ChangeNotifierProvider<LoginProvider>(
          create: (ctx) {
            final loginProvider = LoginProvider();
            loginProvider.init();
            // 延迟到第一帧后设置同步回调，确保其他 Provider 已就绪
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setupSyncCallbacks(loginProvider, ctx);
            });
            return loginProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '笔程',
            debugShowCheckedModeBanner: false,
            // Material 3 主题：浅色/深色跟随系统
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            // 性能优化（关键）：禁用 MaterialApp 默认的 200ms 主题过渡动画。
            //
            // 原本主题切换时，MaterialApp 内部的 AnimatedTheme 会在 200ms 内
            // 逐帧插值 ThemeData，每帧都触发整树 rebuild（所有 Theme.of(context)
            // 依赖的 widget 都会重建）。子树庞大时（5 个一级页 + 列表 + 图表），
            // 这 200ms 内每帧 build 都很重，导致明显掉帧。
            //
            // 设为 Duration.zero 后主题瞬时切换，仅发生一次 rebuild，
            // 彻底消除过渡期间的多帧卡顿。
            themeAnimationDuration: Duration.zero,
            // 命名路由：初始进入主框架 Shell
            initialRoute: AppRouter.initialRoute,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
