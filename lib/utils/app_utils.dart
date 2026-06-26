/// 通用工具：日期、格式化等
///
/// 反焦虑文案工具：统一使用温和正向的词汇。
/// - 不使用「失败」→ 用「今日未完成」
/// - 不使用「断签」→ 用「未完成 / 可补签」
/// - 不使用「惩罚」→ 用「调整」
/// - 不使用「警告」→ 用「提醒」
/// - 不使用「必须」→ 用「可以」
class AppUtils {
  AppUtils._();

  /// 温和的日期文案（如「6月26日 周四」）
  static String friendlyDate(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
  }

  /// 时长格式化：分钟 → 「X小时Y分」
  static String formatDuration(int minutes) {
    if (minutes <= 0) return '0 分';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m 分';
    if (m == 0) return '$h 小时';
    return '$h 小时 $m 分';
  }
}
