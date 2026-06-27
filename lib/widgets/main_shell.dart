import 'package:flutter/material.dart';
import '../pages/home/home_page.dart';
import '../pages/focus/focus_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/group/group_page.dart';
import '../pages/profile/profile_page.dart';

/// 主框架 Shell：承载底部导航栏 + 5 个一级页面
///
/// 设计要点：
/// 1. 使用 [IndexedStack] 保持各页面状态，切换流畅无卡顿、无白屏
/// 2. 默认选中首页（index=0）
/// 3. 底部导航无浮起阴影、无强对比，符合极简无打扰原则
/// 4. 文案温和：5 个 Tab 分别为「今日/专注/统计/模板/我的」
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 当前选中的 Tab 索引，默认 0 = 首页
  int _currentIndex = 0;

  /// 5 个一级页面（const 构造，IndexedStack 复用，切换流畅）
  ///
  /// 性能优化：每个页面外层包裹 [RepaintBoundary]，
  /// 在主题切换（整树重建）或某一页notifyListeners时，
  /// 限制重绘范围避免波及其他页面，减少 GPU 合成开销。
  static final List<Widget> _pages = <Widget>[
    RepaintBoundary(child: HomePage()),
    RepaintBoundary(child: FocusPage()),
    RepaintBoundary(child: StatsPage()),
    RepaintBoundary(child: GroupPage()),
    RepaintBoundary(child: ProfilePage()),
  ];

  /// 底部导航项配置
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.check_circle_outline),
      selectedIcon: Icon(Icons.check_circle),
      label: '今日',
    ),
    NavigationDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: '专注',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: '统计',
    ),
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: '模板',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack：仅构建当前页，但保留全部页面状态，切换不重建
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 底部导航栏：Material 3 NavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // 切换 Tab，setState 触发轻量重建（仅导航高亮变化）
          setState(() => _currentIndex = index);
        },
        destinations: _destinations,
      ),
    );
  }
}
