import 'package:flutter/material.dart';

/// 应用色彩规范
///
/// 设计原则：
/// 1. 主色采用低饱和度莫兰迪蓝（#6B8E9F），传递平和、专注的备考氛围
/// 2. 辅助色柔和绿色，用于完成/正向状态反馈
/// 3. 避免高饱和刺眼配色，错误提示不用纯红，统一用暖灰/沉静色
/// 4. 文字层级清晰，保证大面积留白下的可读性
class AppColors {
  AppColors._(); // 私有构造，禁止实例化

  // ===== 品牌主色：莫兰迪蓝 =====
  /// 主色：莫兰迪蓝 #6B8E9F
  static const Color primary = Color(0xFF6B8E9F);

  /// 主色亮调（用于浅色按钮、选中态）
  static const Color primaryLight = Color(0xFFA4C0CC);

  /// 主色深调（用于深色模式或文字强调）
  static const Color primaryDark = Color(0xFF4A6B7A);

  // ===== 辅助色：柔和绿色 =====
  /// 辅助色：柔和绿 #9DB4A0，用于完成/正向反馈
  static const Color secondary = Color(0xFF9DB4A0);

  static const Color secondaryLight = Color(0xFFCFDDD0);

  // ===== 功能色（低饱和，避免焦虑） =====
  /// 温暖提示色：琥珀灰 #C9A876，用于补签/休息日
  static const Color warm = Color(0xFFC9A876);

  /// 中性强调色：石板灰 #7A8B99
  static const Color neutral = Color(0xFF7A8B99);

  // ===== 文字层级 =====
  static const Color textPrimary = Color(0xFF2C3E44); // 主文字：深青灰
  static const Color textSecondary = Color(0xFF6B7C84); // 次文字：中灰
  static const Color textHint = Color(0xFF9AA7AD); // 提示文字：浅灰

  // ===== 分隔线 =====
  static const Color divider = Color(0xFFE0E4E6); // 分隔线：柔和浅灰

  // ===== 浅色模式背景与表面 =====
  static const Color lightBg = Color(0xFFF7F6F2); // 暖白背景，柔和不刺眼
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF2F1ED); // 卡片底色

  // ===== 深色模式背景与表面 =====
  static const Color darkBg = Color(0xFF1E2428);
  static const Color darkSurface = Color(0xFF262D31);
  static const Color darkCard = Color(0xFF2E363B);

  // ===== 错误提示（温和、不制造负罪感） =====
  /// 错误色用沉静的陶土红，不刺眼
  static const Color error = Color(0xFFB07D6E);
  static const Color onError = Color(0xFFFFFFFF);
}
