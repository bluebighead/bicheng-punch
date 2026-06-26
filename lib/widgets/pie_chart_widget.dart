import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 图表模式枚举
enum ChartMode {
  pie,   // 饼图模式
  bar,   // 横向条形图模式
}

/// 科目/习惯占比图表组件（支持饼图和横向条形图切换）
///
/// 反焦虑设计原则：
/// - 柔和配色，与整体主题统一
/// - 清晰直观的科目/习惯占比展示
/// - 右上角切换按钮，可在饼图和条形图间切换
/// - 条形图显示具体学习时长，便于精确对比
class PieChartWidget extends StatefulWidget {
  const PieChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.showLegend = true,
  });

  final Map<String, int> data; // 名称 -> 时长（分钟）
  final String title;
  final bool showLegend;

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  /// 当前图表模式，默认饼图
  ChartMode _chartMode = ChartMode.pie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(
                      '还没有数据',
                      style: TextStyle(color: AppColors.textHint, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '开始专注学习后，这里会显示科目占比',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 计算总时长
    final totalMinutes = widget.data.values.fold(0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏 + 切换按钮
          Row(
            children: [
              Expanded(child: Text(widget.title, style: theme.textTheme.titleMedium)),
              // 饼图/条形图切换按钮
              GestureDetector(
                onTap: () {
                  setState(() {
                    _chartMode = _chartMode == ChartMode.pie
                        ? ChartMode.bar
                        : ChartMode.pie;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _chartMode == ChartMode.pie
                            ? Icons.pie_chart
                            : Icons.bar_chart,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _chartMode == ChartMode.pie ? '饼图' : '条形图',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 图表内容
          _chartMode == ChartMode.pie
              ? _buildPieChart(theme, totalMinutes)
              : _buildBarChart(theme, totalMinutes),
        ],
      ),
    );
  }

  /// 饼图模式
  Widget _buildPieChart(ThemeData theme, int totalMinutes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 饼图
        Expanded(
          flex: 3,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: PieChartPainter(
                data: widget.data,
                colors: _getChartColors(widget.data.length),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 图例
        if (widget.showLegend)
          Expanded(
            flex: 2,
            child: _buildLegend(theme, totalMinutes),
          ),
      ],
    );
  }

  /// 横向条形图模式
  Widget _buildBarChart(ThemeData theme, int totalMinutes) {
    final entries = widget.data.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value)); // 按时长降序
    final maxValue = entries.first.value;

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
        final percentage = totalMinutes > 0
            ? (item.value / totalMinutes * 100).toStringAsFixed(1)
            : '0.0';
        final color = _getChartColors(widget.data.length)[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称行
              Row(
                children: [
                  // 颜色标记
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 科目名称
                  Expanded(
                    child: Text(
                      item.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 时长和百分比
                  Text(
                    '${item.value}分钟 · $percentage%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 横向条形图（用 Container 宽度表示占比）
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: math.max(ratio, 0.02), // 最小2%宽度，方便识别
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${item.value}分钟',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建图例
  Widget _buildLegend(ThemeData theme, int totalMinutes) {
    final entries = widget.data.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final percentage = totalMinutes > 0
            ? (item.value / totalMinutes * 100).toStringAsFixed(1)
            : '0.0';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getChartColors(widget.data.length)[index],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.key,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$percentage%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 获取图表颜色列表（柔和配色）
  List<Color> _getChartColors(int count) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.primaryLight,
      AppColors.secondaryLight,
      AppColors.warm,
      AppColors.neutral,
      Color(0xFFB8A9C9),
      Color(0xFFC9B8A9),
      Color(0xFFA9C9B8),
      Color(0xFFC9A9B8),
    ];

    final result = <Color>[];
    for (int i = 0; i < count; i++) {
      result.add(colors[i % colors.length]);
    }
    return result;
  }
}

/// 饼图绘制器（纯 Flutter CustomPainter，无外部依赖）
class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  PieChartPainter({
    required this.data,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;

    final totalMinutes = data.values.fold(0, (sum, val) => sum + val);
    if (totalMinutes == 0) return;

    final entries = data.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));

    double startAngle = -math.pi / 2;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final sweepAngle = (entry.value / totalMinutes) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      final separatorPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        separatorPaint,
      );

      startAngle += sweepAngle;
    }

    // 中心圆
    final centerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, centerCirclePaint);

    // 中心总时长
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final textPainter = TextPainter(
      text: TextSpan(
        text: hours > 0 ? '$hours小时' : '$minutes分钟',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    if (data.length != oldDelegate.data.length) return true;
    final entries = data.entries.toList();
    final oldEntries = oldDelegate.data.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].key != oldEntries[i].key ||
          entries[i].value != oldEntries[i].value) {
        return true;
      }
    }
    return false;
  }
}
