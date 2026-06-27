import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 折线图组件 - 使用 Flutter 内置 CustomPainter 绘制
///
/// 反焦虑设计原则：
/// - 柔和配色，与整体主题统一
/// - 展示每日学习时长变化趋势
/// - 无刺眼对比色，不强调失败或退步
class LineChartWidget extends StatelessWidget {
  const LineChartWidget({
    super.key,
    required this.data,
    required this.title,
    required this.isWeekView,
  });

  final Map<DateTime, int> data; // 日期 -> 时长（分钟）
  final String title;
  final bool isWeekView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                // 显示数据点数（调试辅助）
                Text(
                  '${data.length}天数据',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 图表区域
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusM),
            ),
            child: SizedBox(
              height: 200,
              child: data.isEmpty
                  ? _buildEmptyState()
                  : RepaintBoundary(
                      child: CustomPaint(
                        painter: _SimpleLineChartPainter(
                          data: data,
                          isWeekView: isWeekView,
                          lineColor: AppColors.primary,
                          dotColor: AppColors.primary,
                          gridColor: AppColors.divider,
                          // 性能优化+主题适配：数据点内圈使用卡片色，
                          // 深色模式下不再硬白刺眼；shouldRepaint 加入对比，主题切换才重绘
                          innerDotColor: theme.cardColor,
                          axisLabelColor: AppColors.textSecondary,
                        ),
                        size: const Size(double.infinity, 200),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 空状态：显示柔和提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            '还没有数据',
            style: TextStyle(fontSize: 14, color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(
            '开始专注学习后，这里会显示你的时长趋势',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

/// 简化的折线图绘制器 - 只使用最基本的 Canvas 绘制 API
class _SimpleLineChartPainter extends CustomPainter {
  final Map<DateTime, int> data;
  final bool isWeekView;
  final Color lineColor;
  final Color dotColor;
  final Color gridColor;

  /// 数据点内圈颜色（原硬编码 Colors.white，深色模式不适配）
  final Color innerDotColor;

  /// X/Y 轴标签文字颜色
  final Color axisLabelColor;

  // 图表内边距
  static const double _left = 36;
  static const double _right = 8;
  static const double _top = 8;
  static const double _bottom = 28;

  _SimpleLineChartPainter({
    required this.data,
    required this.isWeekView,
    required this.lineColor,
    required this.dotColor,
    required this.gridColor,
    required this.innerDotColor,
    required this.axisLabelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final chartW = size.width - _left - _right;
    final chartH = size.height - _top - _bottom;

    if (chartW <= 0 || chartH <= 0) return;

    // 计算最大值
    int maxVal = 1;
    for (final e in entries) {
      if (e.value > maxVal) maxVal = e.value;
    }
    // 向上取整到最接近的10的倍数，方便阅读
    maxVal = ((maxVal / 10).ceil()) * 10;
    if (maxVal == 0) maxVal = 10;

    // ---- 1. 绘制网格线 ----
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = _top + (chartH / 4) * i;
      canvas.drawLine(
        Offset(_left, y),
        Offset(_left + chartW, y),
        gridPaint,
      );
    }

    // ---- 2. 计算每个点的位置 ----
    final n = entries.length;
    final stepX = n > 1 ? chartW / (n - 1) : chartW / 2;

    // ---- 3. 绘制填充区域 ----
    if (n >= 2) {
      final fillPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(_left, _top + chartH);

      for (int i = 0; i < n; i++) {
        final x = _left + stepX * i;
        final y = _top + chartH - (entries[i].value / maxVal) * chartH;
        path.lineTo(x, y);
      }

      path.lineTo(_left + chartW, _top + chartH);
      path.close();
      canvas.drawPath(path, fillPaint);

      // ---- 4. 绘制折线 ----
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final linePath = Path();
      for (int i = 0; i < n; i++) {
        final x = _left + stepX * i;
        final y = _top + chartH - (entries[i].value / maxVal) * chartH;
        if (i == 0) {
          linePath.moveTo(x, y);
        } else {
          linePath.lineTo(x, y);
        }
      }
      canvas.drawPath(linePath, linePaint);
    }

    // ---- 5. 绘制数据点 ----
    for (int i = 0; i < n; i++) {
      final x = _left + stepX * i;
      final y = _top + chartH - (entries[i].value / maxVal) * chartH;

      // 外圈：主题色
      canvas.drawCircle(
        Offset(x, y),
        4.5,
        Paint()..color = dotColor..style = PaintingStyle.fill,
      );
      // 内圈：使用传入的主题卡片色（适配深色模式）
      canvas.drawCircle(
        Offset(x, y),
        2.0,
        Paint()..color = innerDotColor..style = PaintingStyle.fill,
      );
    }

    // ---- 6. 绘制 X 轴标签 ----
    final xTextStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 10,
    );
    final step = n > 14 ? (n / 7).ceil() : 1;

    for (int i = 0; i < n; i += step) {
      final x = _left + stepX * i;
      final date = entries[i].key;

      String label;
      if (isWeekView) {
        const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        label = days[(date.weekday - 1) % 7];
      } else {
        label = '${date.day}日';
      }

      final tp = TextPainter(
        text: TextSpan(text: label, style: xTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, _top + chartH + 6));
    }

    // ---- 7. 绘制 Y 轴标签 ----
    final yTextStyle = TextStyle(
      color: axisLabelColor,
      fontSize: 9,
    );

    for (int i = 0; i <= 4; i++) {
      final value = (maxVal / 4) * (4 - i);
      final y = _top + (chartH / 4) * i;

      final tp = TextPainter(
        text: TextSpan(text: '${value.toInt()}', style: yTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_left - tp.width - 4, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleLineChartPainter oldDelegate) {
    // 性能优化：数据长度不同则重绘
    if (data.length != oldDelegate.data.length) return true;
    // 逐条比较数据
    final e1 = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final e2 = oldDelegate.data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    for (int i = 0; i < e1.length; i++) {
      if (e1[i].key != e2[i].key || e1[i].value != e2[i].value) return true;
    }
    // 主题相关颜色变化时也重绘（深浅模式切换）
    return lineColor != oldDelegate.lineColor ||
        dotColor != oldDelegate.dotColor ||
        gridColor != oldDelegate.gridColor ||
        innerDotColor != oldDelegate.innerDotColor ||
        axisLabelColor != oldDelegate.axisLabelColor;
  }
}
