import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/template_service.dart';
import '../../models/habit_model.dart';
import '../../providers/habit_provider.dart';

/// 小组页：备考计划模板（轻量）
///
/// 差异化：内置备考专属计划模板（考研/考公/教资/四六级），
/// 一键添加，无需从零创建。无公开广场、无点赞排名。
///
/// 功能：
/// 1. 展示备考分类卡片，点击进入对应模板列表
/// 2. 模板列表展示各科目名称、图标、频率和描述
/// 3. 一键添加所有模板习惯
class GroupPage extends StatefulWidget {
  const GroupPage({super.key});

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  ExamCategory? _selectedCategory; // 当前选中的备考分类
  List<HabitTemplate>? _templates; // 当前分类的模板列表
  bool _isAdding = false; // 是否正在添加中

  /// 备考分类名称映射（中文）
  static const Map<ExamCategory, String> _categoryNames = {
    ExamCategory.kaoyan: '考研',
    ExamCategory.kaogong: '考公',
    ExamCategory.jiaozhi: '教资',
    ExamCategory.cet4cet6: '四六级',
    ExamCategory.custom: '自定义',
  };

  /// 备考分类描述
  static const Map<ExamCategory, String> _categoryDescs = {
    ExamCategory.kaoyan: '考研冲刺，专业课+公共课系统备考',
    ExamCategory.kaogong: '行测+申论，分模块高效练习',
    ExamCategory.jiaozhi: '综合素质+教育知识，教资必备',
    ExamCategory.cet4cet6: '单词+听力+阅读，四六级通关',
    ExamCategory.custom: '从零开始，自由创建你的习惯',
  };

  /// 备考分类图标
  static const Map<ExamCategory, IconData> _categoryIcons = {
    ExamCategory.kaoyan: Icons.school,
    ExamCategory.kaogong: Icons.quiz,
    ExamCategory.jiaozhi: Icons.psychology,
    ExamCategory.cet4cet6: Icons.translate,
    ExamCategory.custom: Icons.auto_awesome,
  };

  /// 备考分类配色
  static const Map<ExamCategory, Color> _categoryColors = {
    ExamCategory.kaoyan: AppColors.primary,
    ExamCategory.kaogong: AppColors.secondary,
    ExamCategory.jiaozhi: AppColors.warm,
    ExamCategory.cet4cet6: Color(0xFF7A8B99),
    ExamCategory.custom: AppColors.textHint,
  };

  /// 备考分类背景色
  static const Map<ExamCategory, Color> _categoryBgColors = {
    ExamCategory.kaoyan: AppColors.primaryLight,
    ExamCategory.kaogong: AppColors.secondaryLight,
    ExamCategory.jiaozhi: Color(0xFFFFECD2),
    ExamCategory.cet4cet6: Color(0xFFE8EDF0),
    ExamCategory.custom: Color(0xFFF0F0F0),
  };

  /// 选择备考分类，加载对应模板
  void _selectCategory(ExamCategory category) {
    setState(() {
      _selectedCategory = category;
      if (category == ExamCategory.custom) {
        _templates = [];
      } else {
        _templates = TemplateService.getTemplatesByCategory(category);
      }
    });
  }

  /// 一键添加所有模板习惯
  Future<void> _addAllTemplates() async {
    if (_selectedCategory == null || _templates == null || _templates!.isEmpty) {
      return;
    }

    setState(() => _isAdding = true);

    try {
      final habitProvider = context.read<HabitProvider>();
      await habitProvider.addTemplatesFromCategory(_selectedCategory!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加 ${_templates!.length} 个习惯，开始备考之旅吧！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // 添加完成后返回主页
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败，请稍后重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isAdding = false);
    }
  }

  /// 显示添加确认弹窗
  void _showAddConfirmDialog() {
    if (_templates == null || _templates!.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        title: Row(
          children: [
            Icon(
              _categoryIcons[_selectedCategory] ?? Icons.auto_stories,
              size: 24,
              color: _categoryColors[_selectedCategory],
            ),
            const SizedBox(width: 8),
            Text('添加${_categoryNames[_selectedCategory]}模板'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将一次性添加以下 ${_templates!.length} 个习惯：'),
            const SizedBox(height: 12),
            ..._templates!.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_iconFromString(t.icon), size: 20, color: Color(t.color)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.name)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            Text(
              '你可以随时在首页编辑或删除习惯',
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _addAllTemplates();
            },
            child: const Text('一键添加'),
          ),
        ],
      ),
    );
  }

  /// 将字符串图标名转为 IconData
  IconData _iconFromString(String iconName) {
    switch (iconName) {
      case 'menu_book':
        return Icons.menu_book;
      case 'calculate':
        return Icons.calculate;
      case 'school':
        return Icons.school;
      case 'article':
        return Icons.article;
      case 'quiz':
        return Icons.quiz;
      case 'edit_note':
        return Icons.edit_note;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'psychology':
        return Icons.psychology;
      case 'fact_check':
        return Icons.fact_check;
      case 'description':
        return Icons.description;
      case 'translate':
        return Icons.translate;
      case 'headphones':
        return Icons.headphones;
      case 'auto_stories':
        return Icons.auto_stories;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: () {
                  // 返回备考分类选择页
                  setState(() => _selectedCategory = null);
                },
              )
            : const SizedBox.shrink(),
        title: Text(_selectedCategory == null ? '计划模板' : _categoryNames[_selectedCategory] ?? ''),
      ),
      body: SafeArea(
        child: _selectedCategory == null
            ? _buildCategorySelection(theme)
            : _buildTemplateList(theme),
      ),
    );
  }

  /// 构建备考分类选择页
  Widget _buildCategorySelection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('一键添加备考计划', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            '选择你的备考类型，快速添加对应习惯模板',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),

          // 备考分类卡片列表
          Expanded(
            child: ListView.separated(
              itemCount: ExamCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = ExamCategory.values[index];
                return _buildCategoryCard(theme, category);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个备考分类卡片
  Widget _buildCategoryCard(ThemeData theme, ExamCategory category) {
    final color = _categoryColors[category]!;
    final bgColor = _categoryBgColors[category]!;
    final icon = _categoryIcons[category]!;
    final name = _categoryNames[category]!;
    final desc = _categoryDescs[category]!;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: category == ExamCategory.custom
            ? null // 自定义类型暂不可用
            : () => _selectCategory(category),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 分类图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),

              // 分类文字描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // 箭头
              Icon(
                category == ExamCategory.custom
                    ? Icons.lock_outline
                    : Icons.chevron_right,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建模板列表页
  Widget _buildTemplateList(ThemeData theme) {
    if (_templates == null || _templates!.isEmpty) {
      return _buildEmptyTemplate(theme);
    }

    return Column(
      children: [
        // 模板列表
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePaddingH),
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _templates!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final template = _templates![index];
                return _buildTemplateCard(theme, template);
              },
            ),
          ),
        ),

        // 底部一键添加按钮
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePaddingH,
              12,
              AppTheme.pagePaddingH,
              16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isAdding ? null : _showAddConfirmDialog,
                icon: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(_isAdding ? '添加中...' : '一键添加 ${_templates!.length} 个习惯'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建模板卡片
  Widget _buildTemplateCard(ThemeData theme, HabitTemplate template) {
    final color = Color(template.color);

    // 频率文本
    String freqText;
    switch (template.frequencyType) {
      case FrequencyType.daily:
        freqText = '每日打卡';
        break;
      case FrequencyType.weeklyX:
        freqText = '每周 ${template.weeklyCount ?? 5} 次';
        break;
      case FrequencyType.customDays:
        freqText = '自定义日期';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 习惯图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFromString(template.icon),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // 习惯名称、描述和频率
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (template.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    template.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    freqText,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 选中标记
          Icon(
            Icons.check_circle,
            color: color.withValues(alpha: 0.4),
            size: 22,
          ),
        ],
      ),
    );
  }

  /// 构建空模板状态
  Widget _buildEmptyTemplate(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              '自定义备考计划',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '此功能即将开放，敬请期待',
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
