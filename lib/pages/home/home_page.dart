import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../models/habit_model.dart';
import '../../models/check_in_model.dart';
import '../../providers/habit_provider.dart';
import '../../providers/check_in_provider.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/month_calendar.dart';

/// 首页：今日打卡概览
///
/// 核心功能：
/// 1. 展示今日所有习惯，卡片式布局
/// 2. 点击卡片一键打卡，打卡后卡片变柔和填充色，搭配轻微震动反馈
/// 3. 右上角日历按钮点击弹出月历视图，查看历史打卡/补签
///
/// 反焦虑设计：
/// - 弱化连续天数，突出累计与完成率
/// - 休息日不计入，放松一下也没关系
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ===== 批量操作状态 =====
  /// 是否处于批量操作模式
  bool _batchMode = false;

  /// 选中的习惯 ID 集合
  final Set<String> _selectedIds = <String>{};

  /// 进入批量操作模式
  void _enterBatchMode() {
    setState(() {
      _batchMode = true;
      _selectedIds.clear();
    });
  }

  /// 退出批量操作模式
  void _exitBatchMode() {
    setState(() {
      _batchMode = false;
      _selectedIds.clear();
    });
  }

  /// 切换单个习惯的选中状态
  void _toggleSelect(String habitId) {
    setState(() {
      if (_selectedIds.contains(habitId)) {
        _selectedIds.remove(habitId);
      } else {
        _selectedIds.add(habitId);
      }
    });
  }

  /// 全选/取消全选（基于当前 todayHabits）
  void _toggleSelectAll(List<Habit> todayHabits) {
    setState(() {
      if (_selectedIds.length == todayHabits.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(todayHabits.map((h) => h.id));
      }
    });
  }

  /// 刷新数据
  void _refreshData() {
    context.read<HabitProvider>().loadHabits();
    context.read<CheckInProvider>().loadCheckIns();
  }

  /// 弹出月历视图（底部弹窗）
  void _showCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _CalendarSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitProvider = context.watch<HabitProvider>();
    final checkInProvider = context.watch<CheckInProvider>();

    // 今日需打卡的习惯列表（HabitProvider 已缓存，O(1)）
    final todayHabits = habitProvider.getTodayHabits();

    // 今日已打卡习惯 ID 集合（CheckInProvider 已缓存，O(1) 查询）
    // 性能优化：原对每个 habit 调用 isCheckedIn 逐个 .any() 遍历全部 checkIns，
    // 现改为一次性获取今日打卡 Set，查询 O(1)
    final todayCheckedIds = checkInProvider.getTodayCheckedHabitIds();

    // 今日已打卡数量
    final todayCheckedCount =
        todayHabits.where((h) => todayCheckedIds.contains(h.id)).length;

    // 今日完成率
    final todayCompletionRate = todayHabits.isEmpty
        ? 0.0
        : todayCheckedCount / todayHabits.length;

    return PopScope(
      // 批量模式下拦截返回键，改为退出批量模式而非离开页面
      canPop: !_batchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitBatchMode();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: '添加打卡项',
          onPressed: () {
            Navigator.pushNamed(context, '/group');
          },
        ),
        title: const Text('今日打卡'),
        actions: [
          // 日历按钮：点击弹出月历视图
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _showCalendar,
            tooltip: '历史打卡',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // 统计概览卡片
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePaddingH),
                child: _buildStatsOverview(
                    theme, todayCheckedCount, todayHabits.length, todayCompletionRate),
              ),

              const SizedBox(height: 16),

              // 今日习惯列表
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('今日待打卡', style: theme.textTheme.titleLarge),
                        if (todayHabits.isNotEmpty && !_batchMode)
                          Row(
                            children: [
                              Text(
                                '$todayCheckedCount/${todayHabits.length}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 批量操作按钮
                              IconButton(
                                icon: const Icon(Icons.checklist, size: 22),
                                tooltip: '批量操作',
                                onPressed: _enterBatchMode,
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ===== 批量操作工具条（仅批量模式下显示）=====
                    if (_batchMode)
                      _buildBatchToolbar(theme, todayHabits),

                    // 习惯卡片列表或空状态
                    if (habitProvider.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (todayHabits.isEmpty)
                      _buildEmptyState(theme)
                    else
                      _buildGroupedHabitList(theme, todayHabits, checkInProvider, todayCheckedIds),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// 构建统计概览卡片
  Widget _buildStatsOverview(
      ThemeData theme, int checked, int total, double rate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日进度', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(rate * 100).toInt()}%',
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  total == 0
                      ? '添加习惯开始备考之旅'
                      : checked == total
                          ? '今日已完成，休息一下也没关系'
                          : '稳步前行，一次就好',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            // 进度条
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建批量操作工具条
  ///
  /// 包含：全选/取消全选、删除选中、退出批量模式
  Widget _buildBatchToolbar(ThemeData theme, List<Habit> todayHabits) {
    final allSelected = todayHabits.isNotEmpty &&
        _selectedIds.length == todayHabits.length;
    final selectedCount = _selectedIds.length;

    // 选中的习惯中，属于自定义分类（examCategory == custom）的数量
    // 仅自定义习惯可被重新分组，故据此决定「分类组命名」按钮是否可用
    final selectedCustomCount = todayHabits
        .where((h) =>
            _selectedIds.contains(h.id) &&
            h.examCategory == ExamCategory.custom)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusM)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：全选 / 退出
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _toggleSelectAll(todayHabits),
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  size: 20,
                ),
                label: Text(allSelected ? '取消全选' : '全选'),
              ),
              const Spacer(),
              if (selectedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '已选 $selectedCount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              // 退出批量模式
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: '退出批量操作',
                onPressed: _exitBatchMode,
              ),
            ],
          ),
          // 第二行：删除 / 分类组命名（选中数 > 0 时显示）
          if (selectedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  // 分类组命名按钮：仅当选中项含自定义习惯时可用
                  TextButton.icon(
                    onPressed: selectedCustomCount > 0
                        ? () => _showCategoryNameDialog(todayHabits)
                        : null,
                    icon: const Icon(Icons.folder_outlined, size: 20),
                    label: Text(
                      selectedCustomCount > 0
                          ? '分类组命名($selectedCustomCount)'
                          : '分类组命名',
                    ),
                  ),
                  const Spacer(),
                  // 删除按钮
                  TextButton.icon(
                    onPressed: () => _confirmBatchDelete(todayHabits),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: Text('删除($selectedCount)'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 批量删除确认对话框
  ///
  /// 二次确认后删除所有选中的习惯及其打卡记录
  void _confirmBatchDelete(List<Habit> todayHabits) {
    final selectedHabits = todayHabits
        .where((h) => _selectedIds.contains(h.id))
        .toList();

    if (selectedHabits.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除'),
        content: Text(
          '确定删除选中的 ${selectedHabits.length} 个习惯吗？\n'
          '删除后将同时清除这些习惯的所有打卡记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performBatchDelete(selectedHabits);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 执行批量删除
  ///
  /// 遍历选中习惯，逐个删除其打卡记录与习惯本身，完成后退出批量模式
  void _performBatchDelete(List<Habit> habits) {
    final checkInProvider = context.read<CheckInProvider>();
    final habitProvider = context.read<HabitProvider>();

    for (final habit in habits) {
      // 清理该习惯的所有打卡记录
      final habitCheckIns = checkInProvider.getCheckInsByHabit(habit.id);
      for (final checkIn in habitCheckIns) {
        checkInProvider.cancelCheckIn(checkIn.id);
      }
      // 删除习惯
      habitProvider.removeHabit(habit.id);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除 ${habits.length} 个习惯'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 退出批量模式
    _exitBatchMode();
  }

  /// 显示「分类组命名」对话框
  ///
  /// 仅对选中的自定义习惯（examCategory == custom）生效：
  /// 用户输入新的分类组名称后，选中的自定义习惯归入该组；
  /// 未选中的习惯保持原分组不变。
  void _showCategoryNameDialog(List<Habit> todayHabits) {
    // 筛选出选中的自定义习惯
    final selectedCustomHabits = todayHabits
        .where((h) =>
            _selectedIds.contains(h.id) &&
            h.examCategory == ExamCategory.custom)
        .toList();

    if (selectedCustomHabits.isEmpty) return;

    final theme = Theme.of(context);
    final controller = TextEditingController();
    // 收集已存在的自定义分类组名称，供用户参考
    final existingGroups = <String>{};
    for (final h in todayHabits) {
      final cat = h.customCategory?.trim();
      if (cat != null && cat.isNotEmpty && cat != kDefaultCustomGroupName) {
        existingGroups.add(cat);
      }
    }

    showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('分类组命名'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '将选中的 ${selectedCustomHabits.length} 个自定义打卡项归入新的分类组：',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: '分类组名称',
                  hintText: '例如：日常、阅读、运动',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(12),
                ],
              ),
              if (existingGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '已有分类组：${existingGroups.join('、')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            // 取消按钮：关闭弹窗，不执行任何操作
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            // 确定按钮：校验非空后执行分组
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请输入分类组名称'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, name);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    ).then((result) {
      controller.dispose();
      if (result == null) return;
      _performCategorize(selectedCustomHabits, result);
    });
  }

  /// 执行分类组设置
  ///
  /// 将选中的自定义习惯的 customCategory 设置为 [categoryName]，
  /// 完成后退出批量模式。
  Future<void> _performCategorize(
      List<Habit> habits, String categoryName) async {
    final habitProvider = context.read<HabitProvider>();
    final ids = habits.map((h) => h.id).toList();
    await habitProvider.setCustomCategoryForHabits(ids, categoryName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${habits.length} 个打卡项归入「$categoryName」'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 退出批量模式
    _exitBatchMode();
  }

  /// 构建空状态提示
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              '还没有习惯',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.textHint),
            ),
            const SizedBox(height: 8),
            Text(
              '点击左上角 + 或前往「模板」页添加备考计划\n慢慢来，一次一个好习惯',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ===== 分类分组渲染 =====

  /// 模板备考分类的展示顺序（考研 → 考公 → 教资 → 四六级）
  ///
  /// 自定义分类组（含默认「自定义」组）排在模板分类之后。
  static const List<ExamCategory> _templateCategoryOrder = [
    ExamCategory.kaoyan,
    ExamCategory.kaogong,
    ExamCategory.jiaozhi,
    ExamCategory.cet4cet6,
  ];

  /// 将习惯按显示分类分组，并按固定顺序排列
  ///
  /// 排列规则：
  /// 1. 模板分类（考研/考公/教资/四六级）按 [_templateCategoryOrder] 顺序排列
  /// 2. 用户自定义分类组（customCategory 非空）按首次出现顺序排列
  /// 3. 默认「自定义」组排在最后
  ///
  /// 返回有序的 (分类名, 该分类下的习惯列表) 列表。
  List<MapEntry<String, List<Habit>>> _groupHabitsByCategory(
      List<Habit> habits) {
    // 按显示分类名聚合
    final Map<String, List<Habit>> bucket = {};
    // 记录自定义分类组的首次出现顺序
    final List<String> customGroupOrder = [];

    for (final habit in habits) {
      final name = habitDisplayCategory(habit);
      bucket.putIfAbsent(name, () => []);
      bucket[name]!.add(habit);

      // 记录自定义分类组顺序（排除模板分类名与默认「自定义」）
      if (habit.examCategory == ExamCategory.custom &&
          name != kDefaultCustomGroupName &&
          !customGroupOrder.contains(name)) {
        customGroupOrder.add(name);
      }
    }

    // 组装有序结果
    final result = <MapEntry<String, List<Habit>>>[];

    // 1. 模板分类（按固定顺序）
    for (final cat in _templateCategoryOrder) {
      final name = examCategoryNames[cat]!;
      if (bucket.containsKey(name)) {
        result.add(MapEntry(name, bucket[name]!));
      }
    }

    // 2. 用户自定义分类组（按首次出现顺序）
    for (final name in customGroupOrder) {
      if (bucket.containsKey(name)) {
        result.add(MapEntry(name, bucket[name]!));
      }
    }

    // 3. 默认「自定义」组（最后）
    if (bucket.containsKey(kDefaultCustomGroupName)) {
      result.add(MapEntry(kDefaultCustomGroupName, bucket[kDefaultCustomGroupName]!));
    }

    return result;
  }

  /// 判断是否需要显示分类组标题
  ///
  /// 规则：只要存在任意非默认「自定义」组的习惯（模板分类或用户自定义分类组），
  /// 就显示所有分类组标题；若全部习惯都属于默认「自定义」组，则不显示标题（平铺展示）。
  bool _shouldShowCategoryHeaders(List<Habit> habits) {
    for (final h in habits) {
      if (!isHabitInDefaultCustomGroup(h)) return true;
    }
    return false;
  }

  /// 构建分组后的习惯列表
  ///
  /// 根据是否显示分类标题，渲染分组标题 + 习惯卡片。
  /// 批量模式下卡片切换为选中态，非批量模式保留左滑删除。
  Widget _buildGroupedHabitList(
    ThemeData theme,
    List<Habit> todayHabits,
    CheckInProvider checkInProvider,
    Set<String> todayCheckedIds,
  ) {
    final groups = _groupHabitsByCategory(todayHabits);
    final showHeaders = _shouldShowCategoryHeaders(todayHabits);

    final children = <Widget>[];

    for (var i = 0; i < groups.length; i++) {
      final entry = groups[i];
      final categoryName = entry.key;
      final groupHabits = entry.value;

      // 分类标题（按需显示）
      if (showHeaders) {
        if (i > 0) children.add(const SizedBox(height: 16));
        children.add(_buildCategoryHeader(theme, categoryName, groupHabits));
        children.add(const SizedBox(height: 8));
      } else if (i > 0) {
        // 不显示标题时，组与组之间仍保留间距
        children.add(const SizedBox(height: 12));
      }

      // 该分组下的习惯卡片
      for (var j = 0; j < groupHabits.length; j++) {
        if (j > 0) children.add(const SizedBox(height: 12));
        children.add(_buildHabitCardItem(theme, checkInProvider, groupHabits[j], todayCheckedIds));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 构建单个分类组标题
  Widget _buildCategoryHeader(
      ThemeData theme, String categoryName, List<Habit> groupHabits) {
    final isDefault = categoryName == kDefaultCustomGroupName;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: isDefault ? AppColors.textHint : AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          categoryName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDefault ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${groupHabits.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建单个习惯卡片（批量模式/普通模式）
  ///
  /// 性能优化：接收 [todayCheckedIds] 缓存集合，用 Set.contains O(1) 查询
  /// 替代原 isCheckedIn 的 .any() 遍历。
  Widget _buildHabitCardItem(
    ThemeData theme,
    CheckInProvider checkInProvider,
    Habit habit,
    Set<String> todayCheckedIds,
  ) {
    final isCheckedIn = todayCheckedIds.contains(habit.id);
    // getCheckIn 需返回对象，保留原方法（仅打卡状态查询已优化）
    final checkIn = isCheckedIn
        ? checkInProvider.getCheckIn(habit.id, DateTime.now())
        : null;
    final isSelected = _selectedIds.contains(habit.id);

    // 批量模式下：禁用左滑删除，点击卡片切换选中而非打卡
    if (_batchMode) {
      return RepaintBoundary(
        child: HabitCard(
          habit: habit,
          isCheckedIn: isCheckedIn,
          checkIn: checkIn,
          batchMode: true,
          isSelected: isSelected,
          onSelectToggle: () => _toggleSelect(habit.id),
          onTap: () => _toggleSelect(habit.id),
          onLongPress: () {},
        ),
      );
    }

    // 非批量模式：保留左滑删除与打卡点击
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('habit_${habit.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmDialog(context, habit);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        onDismissed: (direction) {
          _deleteHabit(habit);
        },
        child: HabitCard(
          habit: habit,
          isCheckedIn: isCheckedIn,
          checkIn: checkIn,
          onTap: () => _onHabitTap(habit, isCheckedIn),
          onLongPress: () => _showHabitDetail(habit, checkIn),
        ),
      ),
    );
  }

  /// 点击习惯卡片：打卡或取消打卡
  void _onHabitTap(Habit habit, bool isCheckedIn) {
    final checkInProvider = context.read<CheckInProvider>();

    if (isCheckedIn) {
      _showCancelCheckInDialog(habit, checkInProvider);
    } else {
      _performCheckIn(habit, checkInProvider);
    }
  }

  /// 执行打卡操作
  Future<void> _performCheckIn(
      Habit habit, CheckInProvider checkInProvider) async {
    HapticFeedback.lightImpact();

    final success = await checkInProvider.checkIn(
      habit.id,
      DateTime.now(),
      null,
      null,
      null,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('打卡失败，请稍后重试')),
      );
    }
  }

  /// 显示取消打卡确认弹窗
  void _showCancelCheckInDialog(
      Habit habit, CheckInProvider checkInProvider) {
    final checkIn = checkInProvider.getCheckIn(habit.id, DateTime.now());
    if (checkIn == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消打卡'),
        content: Text('确定取消「${habit.name}」的今日打卡吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('保留'),
          ),
          TextButton(
            onPressed: () {
              checkInProvider.cancelCheckIn(checkIn.id);
              Navigator.pop(context);
            },
            child: const Text('取消打卡'),
          ),
        ],
      ),
    );
  }

  /// 长按显示习惯详情
  void _showHabitDetail(Habit habit, CheckIn? checkIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${habit.name} - 长按查看详情（待实现）')),
    );
  }

  /// 显示删除确认弹窗
  Future<bool> _showDeleteConfirmDialog(BuildContext context, Habit habit) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除习惯'),
        content: Text('确定删除「${habit.name}」吗？\n删除后将同时清除该习惯的所有打卡记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 删除习惯及其相关打卡记录
  void _deleteHabit(Habit habit) {
    final checkInProvider = context.read<CheckInProvider>();
    final habitCheckIns = checkInProvider.getCheckInsByHabit(habit.id);
    for (final checkIn in habitCheckIns) {
      checkInProvider.cancelCheckIn(checkIn.id);
    }

    context.read<HabitProvider>().removeHabit(habit.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${habit.name}」'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 月历底部弹窗：包裹 MonthCalendarWidget，支持拖拽关闭
class _CalendarSheet extends StatelessWidget {
  const _CalendarSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部拖拽条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '历史打卡',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 月历内容
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: MonthCalendarWidget(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
