import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../services/storage_service.dart';
import '../../providers/check_in_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/stats_provider.dart';
import '../../routes/app_routes.dart';

/// 我的页：设置 / 补签
///
/// 功能项：
/// 1. 本月补签入口：展示剩余补签次数，点击可查看历史补签
/// 2. 深色模式切换：底部弹窗选择跟随系统/浅色/深色
/// 3. 提醒设置：提醒时间与开关（占位，后续接入通知服务）
/// 4. 休息日设置：选择每周休息日（周六/周日/两者）
/// 5. 关于：版本信息展示
///
/// 反焦虑设计：文案温和，无负面词汇，色彩柔和
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// 当前选择的休息日配置（0=无, 1=周六, 2=周日, 3=都选）
  int _restDayConfig = 3; // 默认周末都休息

  @override
  void initState() {
    super.initState();
    _loadRestDayConfig();
  }

  /// 从配置加载休息日设置
  void _loadRestDayConfig() {
    try {
      final config = StorageService.configBox.get('rest_day_config', defaultValue: 3);
      setState(() {
        _restDayConfig = config as int;
      });
    } catch (e) {
      debugPrint('加载休息日配置失败: $e');
    }
  }

  /// 保存休息日配置
  void _saveRestDayConfig(int config) {
    try {
      StorageService.configBox.put('rest_day_config', config);
      setState(() {
        _restDayConfig = config;
      });
      debugPrint('休息日配置已更新: $config');
    } catch (e) {
      debugPrint('保存休息日配置失败: $e');
    }
  }

  /// 获取休息日文字描述
  String _getRestDayLabel() {
    switch (_restDayConfig) {
      case 0:
        return '无';
      case 1:
        return '周六';
      case 2:
        return '周日';
      case 3:
        return '周末';
      default:
        return '周末';
    }
  }

  /// 显示深色模式选择弹窗
  void _showThemeModeDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final currentMode = themeProvider.themeMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动指示条
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '深色模式',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _ThemeModeOption(
                  title: '跟随系统',
                  subtitle: '自动跟随系统深色模式设置',
                  icon: Icons.settings_suggest_outlined,
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () {
                    // 先关闭弹窗，再切换主题，避免动画冲突导致卡顿
                    Navigator.pop(ctx);
                    Future.microtask(() {
                      themeProvider.setThemeMode(ThemeMode.system);
                    });
                  },
                ),
                _ThemeModeOption(
                  title: '浅色模式',
                  subtitle: '始终使用浅色主题',
                  icon: Icons.light_mode_outlined,
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () {
                    Navigator.pop(ctx);
                    Future.microtask(() {
                      themeProvider.setThemeMode(ThemeMode.light);
                    });
                  },
                ),
                _ThemeModeOption(
                  title: '深色模式',
                  subtitle: '始终使用深色主题',
                  icon: Icons.dark_mode_outlined,
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () {
                    Navigator.pop(ctx);
                    Future.microtask(() {
                      themeProvider.setThemeMode(ThemeMode.dark);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 显示休息日选择弹窗
  void _showRestDayDialog(BuildContext context) {
    int tempConfig = _restDayConfig;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖动指示条
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '休息日设置',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '休息日将不计入打卡完成率',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('周六'),
                      value: tempConfig == 1 || tempConfig == 3,
                      onChanged: (val) {
                        setModalState(() {
                          if (tempConfig == 0) {
                            tempConfig = 1;
                          } else if (tempConfig == 1) {
                            tempConfig = val ? 1 : 0;
                          } else if (tempConfig == 2) {
                            tempConfig = val ? 3 : 2;
                          } else {
                            tempConfig = val ? 3 : 2;
                          }
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('周日'),
                      value: tempConfig == 2 || tempConfig == 3,
                      onChanged: (val) {
                        setModalState(() {
                          if (tempConfig == 0) {
                            tempConfig = 2;
                          } else if (tempConfig == 1) {
                            tempConfig = val ? 3 : 1;
                          } else if (tempConfig == 2) {
                            tempConfig = val ? 2 : 0;
                          } else {
                            tempConfig = val ? 3 : 1;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // 确定按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            _saveRestDayConfig(tempConfig);
                            Navigator.pop(ctx);
                          },
                          child: const Text('确定'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 显示提醒设置页
  void _showReminderSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提醒设置'),
        content: const Text('提醒功能将在后续版本中上线，届时可以设置每日打卡提醒时间和方式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  /// 显示使用说明
  void _showUsageGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.menu_book_outlined, size: 22, color: AppColors.primary),
            SizedBox(width: 8),
            Text('使用说明'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideSection('📋 今日打卡', [
                '点击习惯卡片即可打卡，再次点击可取消打卡',
                '长按卡片查看习惯详情（待实现）',
                '左滑习惯卡片可删除该习惯',
                '下拉展开月历查看历史打卡记录',
                '点击左上角 + 号可跳转模板页添加新习惯',
              ]),
              const SizedBox(height: 16),
              _buildGuideSection('⏱ 专注计时', [
                '进入专注页，点击「开始专注」进入设置页面',
                '选择正计时（自由模式）或倒计时（番茄钟模式）',
                '设置专注时长，支持自定义时长（5-180分钟）',
                '可关联习惯，专注完成后自动打卡',
                '支持白噪音（雨声/咖啡馆/纯音乐）伴学',
              ]),
              const SizedBox(height: 16),
              _buildGuideSection('📊 数据统计', [
                '查看本周学习时长与完成率',
                '查看累计打卡次数与累计学习时长',
                '科目学习时长占比饼图',
                '周/月学习时长趋势折线图',
                '点击右上角日历图标切换周/月视图',
              ]),
              const SizedBox(height: 16),
              _buildGuideSection('📚 计划模板', [
                '内置考研/考公/教资/四六级备考模板',
                '点击分类卡片进入模板列表',
                '一键添加所有模板习惯，快速开始备考',
                '可在首页编辑或删除已添加的习惯',
              ]),
              const SizedBox(height: 16),
              _buildGuideSection('⚙️ 我的设置', [
                '每月可补签遗漏的打卡',
                '支持深色模式切换（跟随系统/浅色/深色）',
                '可设置休息日（不计入完成率）',
                '专注记录会自动统计到数据页',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 构建使用说明中的分区
  Widget _buildGuideSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  /// 显示关于页
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于笔程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('版本：v1.0.0'),
            const SizedBox(height: 12),
            Text(
              '一款面向备考人群的极简打卡工具。\n'
              '核心设计理念：弱化焦虑、容错友好、专注当下。\n\n'
              '支持专注计时、习惯打卡、数据统计、备考模板等功能。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: const Text('我的'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 登录信息卡片（登录后显示用户信息，未登录显示登录入口）
                _buildLoginCard(theme),

                const SizedBox(height: 24),

                // 设置项分组标题
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    '设置',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),

                // 深色模式
                _SettingTile(
                  icon: Icons.dark_mode_outlined,
                  title: '深色模式',
                  trailing: _getThemeModeLabel(context),
                  onTap: () => _showThemeModeDialog(context),
                ),

                // 提醒设置
                _SettingTile(
                  icon: Icons.notifications_none_outlined,
                  title: '提醒',
                  trailing: '未开启',
                  onTap: () => _showReminderSettings(context),
                ),

                // 休息日设置
                _SettingTile(
                  icon: Icons.calendar_month_outlined,
                  title: '休息日设置',
                  trailing: _getRestDayLabel(),
                  onTap: () => _showRestDayDialog(context),
                ),

                const SizedBox(height: 16),

                // 开发分组标题
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    '开发',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),

                // 测试数据开关
                Consumer<StatsProvider>(
                  builder: (context, statsProvider, _) {
                    return _SettingTile(
                      icon: Icons.science_outlined,
                      title: '测试数据',
                      trailing: statsProvider.hasTestData ? '已开启' : '已关闭',
                      onTap: () async {
                        final newState = !statsProvider.hasTestData;
                        await statsProvider.setTestDataEnabled(newState);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(newState ? '测试数据已开启，前往统计页查看效果' : '测试数据已清除'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 信息分组标题
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    '信息',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),

                // 使用说明
                _SettingTile(
                  icon: Icons.menu_book_outlined,
                  title: '使用说明',
                  trailing: '',
                  onTap: () => _showUsageGuideDialog(context),
                ),

                // 关于
                _SettingTile(
                  icon: Icons.info_outline,
                  title: '关于',
                  trailing: 'v1.0.0',
                  onTap: () => _showAboutDialog(context),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建登录信息卡片
  ///
  /// 已登录：显示用户头像、昵称、补签额度、登出按钮
  /// 未登录：显示登录入口卡片，点击跳转登录页
  Widget _buildLoginCard(ThemeData theme) {
    final loginProvider = context.watch<LoginProvider>();
    final checkInProvider = context.watch<CheckInProvider>();

    if (loginProvider.isLoggedIn) {
      // 已登录状态：显示用户信息卡片
      // 补签剩余额度从 CheckInProvider 实时获取（配合 StorageService）
      final remainingQuota = checkInProvider.getRemainingMakeupQuota();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppTheme.radiusM),
          ),
        ),
        child: Row(
          children: [
            // 用户头像占位
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loginProvider.displayName ?? loginProvider.username ?? '用户',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '剩余补签：$remainingQuota 次',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // 登出按钮
            TextButton(
              onPressed: () => _handleLogout(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              child: const Text('登出', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    } else {
      // 未登录状态：显示登录入口卡片
      return GestureDetector(
        onTap: () => _navigateToLogin(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(
              Radius.circular(AppTheme.radiusM),
            ),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.person_outline,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '登录账号',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '登录后同步服务器数据',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      );
    }
  }

  /// 跳转到登录页
  void _navigateToLogin() {
    Navigator.of(context).pushNamed(AppRoutes.login);
  }

  /// 处理登出操作
  Future<void> _handleLogout() async {
    // 在异步前先获取 provider，避免跨异步使用 BuildContext
    final loginProvider = context.read<LoginProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认登出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await loginProvider.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已退出登录'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 获取当前主题模式文字标签
  String _getThemeModeLabel(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    switch (themeProvider.themeMode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }
}

/// 设置项组件（可点击）
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
            Text(trailing, style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 深色模式选项
class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
