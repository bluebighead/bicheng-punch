/// 命名路由表
///
/// 预设 5 个一级页面路由，对应底部导航栏 Tab。
/// 命名规范：小写下划线，语义清晰，避免魔法字符串。
class AppRoutes {
  AppRoutes._();

  /// 主框架（承载底部导航栏的 Shell）
  static const String shell = '/shell';

  // ===== 5 个一级页面 =====
  static const String home = '/home'; // 首页：今日打卡概览
  static const String focus = '/focus'; // 专注页：番茄钟/计时
  static const String stats = '/stats'; // 统计页：周期完成率/累计时长
  static const String group = '/group'; // 小组页：备考计划模板(轻量)
  static const String profile = '/profile'; // 我的页：设置/补签

  // ===== 专注模块 =====
  static const String focusModeSelect = '/focus/mode-select'; // 专注模式选择页
  static const String focusTimer = '/focus/timer'; // 专注计时页

  // ===== 登录模块 =====
  static const String login = '/login'; // 登录页

  // ===== 后续扩展占位（二级页面示例） =====
  // static const String habitDetail = '/habit/detail';
  // static const String punchMakeup = '/punch/makeup';
}
