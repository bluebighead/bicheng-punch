import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 计时器圆环组件
///
/// 功能：
/// 1. 绘制圆环进度（倒计时模式显示剩余时间占比）
/// 2. 显示中心时间文本
/// 3. 支持正计时和倒计时模式
class FocusTimerRing extends StatelessWidget {
  const FocusTimerRing({
    super.key,
    required this.elapsedSeconds,
    this.targetSeconds,
    this.isCountdown = false,
    this.size = 280,
    this.strokeWidth = 8,
  });

  final int elapsedSeconds; // 已计时时长（秒）
  final int? targetSeconds; // 目标时长（秒），倒计时模式有效
  final bool isCountdown; // 是否为倒计时模式
  final double size; // 圆环尺寸
  final double strokeWidth; // 圆环线条宽度

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算进度（0.0 - 1.0）
    double progress = 0.0;
    if (isCountdown && targetSeconds != null && targetSeconds! > 0) {
      // 倒计时：进度 = 已计时时长 / 目标时长
      progress = (elapsedSeconds / targetSeconds!).clamp(0.0, 1.0);
    }

    // 计算显示时间（倒计时显示剩余时间，正计时显示已计时间）
    final displaySeconds = isCountdown && targetSeconds != null
        ? (targetSeconds! - elapsedSeconds).clamp(0, targetSeconds!)
        : elapsedSeconds;

    // 格式化时间
    final timeText = _formatTime(displaySeconds);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TimerRingPainter(
          progress: progress,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeText,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              if (isCountdown) ...[
                const SizedBox(height: 8),
                Text(
                  '目标 ${targetSeconds! ~/ 60} 分钟',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化时间（MM:SS 或 HH:MM:SS）
  String _formatTime(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final secs = seconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }
}

/// 圆环绘制器
class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景圆环
    final bgPaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 进度圆环（仅倒计时模式显示）
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final startAngle = -pi / 2; // 从顶部开始
      final sweepAngle = 2 * pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}