import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 全局主题配置（Material 3）
///
/// 设计规范：
/// 1. 莫兰迪蓝主色 #6B8E9F，辅助色柔和绿
/// 2. 圆角统一 12dp，大量留白
/// 3. 文字层级清晰，主/次/提示三档
/// 4. 浅色/深色模式跟随系统，[ThemeMode.system]
/// 5. 反焦虑：错误色温和，无刺眼红色
class AppTheme {
  AppTheme._();

  /// 统一圆角半径（按需求 12dp）
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusS = 8.0;

  /// 页面统一水平内边距，保证留白
  static const double pagePaddingH = 20.0;

  /// 浅色主题
  static ThemeData get light => _buildTheme(Brightness.light);

  /// 深色主题
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    // 构建 Material 3 ColorScheme
    final colorScheme = ColorScheme(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.warm,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: AppColors.onError,
      surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      onSurface: isLight ? AppColors.textPrimary : const Color(0xFFE8ECEC),
      surfaceContainerHighest:
          isLight ? AppColors.lightCard : AppColors.darkCard,
      onSurfaceVariant: isLight ? AppColors.textSecondary : const Color(0xFFB4BFC4),
      outline: isLight ? const Color(0xFFD9D5CC) : const Color(0xFF3C454A),
      outlineVariant: isLight ? const Color(0xFFEAE7DF) : const Color(0xFF2A3135),
      shadow: isLight ? const Color(0x14000000) : const Color(0x40000000),
      scrim: Colors.black,
      inverseSurface: isLight ? AppColors.darkSurface : AppColors.lightSurface,
      onInverseSurface: isLight ? const Color(0xFFE8ECEC) : AppColors.textPrimary,
      inversePrimary: AppColors.primaryLight,
      surfaceTint: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight ? AppColors.lightBg : AppColors.darkBg,
      canvasColor: isLight ? AppColors.lightBg : AppColors.darkBg,
      // 字体主题：清晰层级
      textTheme: _buildTextTheme(isLight),
      // 应用栏：简洁无阴影
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: isLight ? AppColors.lightBg : AppColors.darkBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      // 卡片：圆角12，柔和阴影
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight ? AppColors.lightCard : AppColors.darkCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusM)),
        ),
        margin: EdgeInsets.zero,
      ),
      // 圆角统一
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusM)),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusM)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radiusM)),
          ),
        ),
      ),
      // 输入框：圆角，柔和边框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusM)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusM)),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radiusM)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      // 底部导航：无浮起阴影，选中色为主色
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? AppColors.lightSurface : AppColors.darkSurface,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.35),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: _fontFamily,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textHint,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primary : AppColors.textHint,
          );
        }),
      ),
      // 分隔线柔和
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      // 圆角通用
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.lightCard : AppColors.darkCard,
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(fontFamily: _fontFamily, fontSize: 13),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusS)),
        ),
      ),
      // 页面切换平滑过渡动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// 字体族（默认系统字体，保证性能与兼容性；null 表示使用平台默认）
  static const String? _fontFamily = null;

  /// 文字层级：展示/标题/正文/标签/提示
  static TextTheme _buildTextTheme(bool isLight) {
    final base = isLight ? AppColors.textPrimary : const Color(0xFFE8ECEC);
    final secondary = isLight ? AppColors.textSecondary : const Color(0xFFB4BFC4);
    final hint = isLight ? AppColors.textHint : const Color(0xFF7A8B99);

    return TextTheme(
      // 大标题：页头/统计数字
      displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: base, height: 1.2),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: base, height: 1.25),
      displaySmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: base, height: 1.3),
      // 区块标题
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: base, height: 1.3),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: base, height: 1.35),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: base, height: 1.4),
      // 卡片标题
      titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: base, height: 1.4),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: base, height: 1.45),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: secondary, height: 1.4),
      // 正文
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: base, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: base, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: secondary, height: 1.45),
      // 标签
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: base, height: 1.4),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: secondary, height: 1.4),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: hint, height: 1.4),
    );
  }
}
