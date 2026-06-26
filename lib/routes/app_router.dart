import 'package:flutter/material.dart';
import 'app_routes.dart';
import '../pages/home/home_page.dart';
import '../pages/focus/focus_page.dart';
import '../pages/focus/focus_mode_select_page.dart';
import '../pages/focus/focus_timer_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/group/group_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/login/login_page.dart';
import '../widgets/main_shell.dart';

/// 路由生成器
///
/// 通过 [onGenerateRoute] 统一管理命名路由跳转，
/// 后续接入新页面只需在此注册，集中维护避免散落。
class AppRouter {
  AppRouter._();

  /// 应用启动初始路由：进入主框架，默认选中首页
  static const String initialRoute = AppRoutes.shell;

  /// 路由生成：根据名称返回对应页面
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.shell:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const MainShell(),
          settings: const RouteSettings(name: AppRoutes.shell),
        );
      case AppRoutes.home:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const HomePage(),
          settings: const RouteSettings(name: AppRoutes.home),
        );
      case AppRoutes.focus:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const FocusPage(),
          settings: const RouteSettings(name: AppRoutes.focus),
        );
      case AppRoutes.focusModeSelect:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const FocusModeSelectPage(),
          settings: const RouteSettings(name: AppRoutes.focusModeSelect),
        );
      case AppRoutes.focusTimer:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const FocusTimerPage(),
          settings: const RouteSettings(name: AppRoutes.focusTimer),
        );
      case AppRoutes.stats:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const StatsPage(),
          settings: const RouteSettings(name: AppRoutes.stats),
        );
      case AppRoutes.group:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const GroupPage(),
          settings: const RouteSettings(name: AppRoutes.group),
        );
      case AppRoutes.profile:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const ProfilePage(),
          settings: const RouteSettings(name: AppRoutes.profile),
        );
      case AppRoutes.login:
        return MaterialPageRoute<dynamic>(
          builder: (_) => const LoginPage(),
          settings: const RouteSettings(name: AppRoutes.login),
        );
      default:
        // 容错：未匹配路由返回首页，避免崩溃
        return MaterialPageRoute<dynamic>(
          builder: (_) => const HomePage(),
          settings: const RouteSettings(name: AppRoutes.home),
        );
    }
  }
}
