import 'dart:async';

/// VoidCallback 类型定义（简化版，避免导入 Flutter）
typedef VoidCallback = void Function();

/// 计时器状态枚举
enum TimerState {
  idle, // 空闲
  running, // 运行中
  paused, // 已暂停
  completed, // 已完成
}

/// 计时器工具类
///
/// 职责：
/// 1. 正计时逻辑（从 0 开始计时）
/// 2. 倒计时逻辑（从目标时长开始倒数）
/// 3. 计时状态管理
/// 4. 计时事件通知
class TimerUtils {
  TimerUtils({
    this.onTick,
    this.onComplete,
  });

  /// 计时回调（每秒触发）
  final void Function(int elapsedSeconds)? onTick;

  /// 完成回调
  final VoidCallback? onComplete;

  Timer? _timer;
  TimerState _state = TimerState.idle;
  int _elapsedSeconds = 0; // 已计时时长（秒）
  int? _targetSeconds; // 目标时长（秒），倒计时模式
  DateTime? _startTime; // 开始时间（用于后台恢复）

  /// 当前计时器状态
  TimerState get state => _state;

  /// 已计时时长（秒）
  int get elapsedSeconds => _elapsedSeconds;

  /// 剩余时长（秒），仅倒计时模式有效
  int? get remainingSeconds {
    if (_targetSeconds == null) return null;
    return (_targetSeconds! - _elapsedSeconds).clamp(0, _targetSeconds!);
  }

  /// 目标时长（秒）
  int? get targetSeconds => _targetSeconds;

  /// 是否为倒计时模式
  bool get isCountdown => _targetSeconds != null;

  /// 开始正计时
  ///
  /// 从 0 开始计时，无上限
  void startStopwatch() {
    if (_state == TimerState.running) return;

    _targetSeconds = null;
    _elapsedSeconds = 0;
    _startTime = DateTime.now();
    _state = TimerState.running;
    _startTimer();
  }

  /// 开始倒计时
  ///
  /// 从 [targetSeconds] 开始倒数到 0
  void startCountdown(int targetSeconds) {
    if (_state == TimerState.running) return;

    _targetSeconds = targetSeconds;
    _elapsedSeconds = 0;
    _startTime = DateTime.now();
    _state = TimerState.running;
    _startTimer();
  }

  /// 暂停计时
  void pause() {
    if (_state != TimerState.running) return;

    _timer?.cancel();
    _timer = null;
    _state = TimerState.paused;
  }

  /// 恢复计时
  void resume() {
    if (_state != TimerState.paused) return;

    // 根据 startTime 计算已过去的时间（应对后台恢复）
    if (_startTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_startTime!).inSeconds;
      _elapsedSeconds = elapsed;
    }

    _state = TimerState.running;
    _startTimer();
  }

  /// 停止计时
  ///
  /// [forced] 是否强制停止（不触发完成回调）
  void stop({bool forced = false}) {
    _timer?.cancel();
    _timer = null;

    if (!forced && _state == TimerState.running) {
      _state = TimerState.completed;
      onComplete?.call();
    } else {
      _state = TimerState.idle;
    }
  }

  /// 重置计时器
  void reset() {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
    _targetSeconds = null;
    _startTime = null;
    _state = TimerState.idle;
  }

  /// 后台恢复时同步计时
  ///
  /// 当应用从后台恢复时，根据开始时间重新计算已计时时长
  void syncFromBackground() {
    if (_startTime == null || _state != TimerState.running) return;

    final now = DateTime.now();
    final elapsed = now.difference(_startTime!).inSeconds;
    _elapsedSeconds = elapsed;

    // 倒计时模式：检查是否已超时
    if (_targetSeconds != null && _elapsedSeconds >= _targetSeconds!) {
      _elapsedSeconds = _targetSeconds!;
      stop(forced: false);
      return;
    }

    onTick?.call(_elapsedSeconds);
  }

  /// 启动定时器（内部方法）
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;

      // 倒计时模式：检查是否到达目标
      if (_targetSeconds != null && _elapsedSeconds >= _targetSeconds!) {
        stop(forced: false);
        return;
      }

      onTick?.call(_elapsedSeconds);
    });
  }

  /// 获取格式化的时间字符串（MM:SS）
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 获取格式化的时间字符串（HH:MM:SS）
  static String formatTimeWithHours(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}