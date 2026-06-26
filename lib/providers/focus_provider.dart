import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/focus_record_model.dart';
import '../models/habit_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../utils/timer_utils.dart';

/// 专注状态管理 Provider
///
/// 职责：
/// 1. 管理专注模式（正计时/倒计时）
/// 2. 管理计时器状态
/// 3. 管理白噪音播放
/// 4. 管理屏幕常亮
/// 5. 关联习惯并在完成后自动打卡
/// 6. 保存专注记录
class FocusProvider extends ChangeNotifier {
  FocusProvider() {
    _init();
  }

  // ===== 状态 =====
  TimerUtils? _timer;
  AudioService? _audioService;

  FocusMode _mode = FocusMode.countdown;
  int _targetMinutes = 25; // 默认 25 分钟
  TimerState _timerState = TimerState.idle;
  int _elapsedSeconds = 0;

  Habit? _linkedHabit; // 关联的习惯
  WhiteNoiseType? _whiteNoiseType; // 当前白噪音
  double _volume = 0.5; // 白噪音音量
  bool _whiteNoiseEnabled = false; // 白噪音是否开启

  List<FocusRecord> _focusRecords = [];
  bool _isLoading = false;

  // ===== Getters =====
  FocusMode get mode => _mode;
  int get targetMinutes => _targetMinutes;
  TimerState get timerState => _timerState;
  int get elapsedSeconds => _elapsedSeconds;
  Habit? get linkedHabit => _linkedHabit;
  WhiteNoiseType? get whiteNoiseType => _whiteNoiseType;
  double get volume => _volume;
  bool get whiteNoiseEnabled => _whiteNoiseEnabled;
  List<FocusRecord> get focusRecords => _focusRecords;
  bool get isLoading => _isLoading;

  /// 剩余时长（秒），倒计时模式有效
  int? get remainingSeconds {
    if (_mode != FocusMode.countdown) return null;
    final target = _targetMinutes * 60;
    return (target - _elapsedSeconds).clamp(0, target);
  }

  /// 获取今日专注次数
  int get todayFocusCount {
    return _focusRecords.where((r) => r.isToday()).length;
  }

  /// 获取今日专注总时长（分钟）
  int get todayFocusMinutes {
    return _focusRecords
        .where((r) => r.isToday())
        .fold(0, (sum, r) => sum + r.duration ~/ 60);
  }

  // ===== 初始化 =====
  Future<void> _init() async {
    _audioService = AudioService();
    await _audioService!.init();
    await loadFocusRecords();
  }

  /// 加载专注记录
  Future<void> loadFocusRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = StorageService.focusRecordBox;
      _focusRecords = box.values.toList();
      debugPrint('加载 ${_focusRecords.length} 条专注记录');
    } catch (e) {
      debugPrint('加载专注记录失败: $e');
      _focusRecords = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ===== 专注模式配置 =====
  /// 设置专注模式
  void setMode(FocusMode mode) {
    if (_timerState != TimerState.idle) return; // 计时中不可切换
    _mode = mode;
    notifyListeners();
  }

  /// 设置目标时长（分钟）
  void setTargetMinutes(int minutes) {
    if (_timerState != TimerState.idle) return;
    _targetMinutes = minutes.clamp(5, 180); // 限制 5-180 分钟
    notifyListeners();
  }

  /// 设置关联习惯
  void setLinkedHabit(Habit? habit) {
    if (_timerState != TimerState.idle) return;
    _linkedHabit = habit;
    notifyListeners();
  }

  // ===== 白噪音控制 =====
  /// 设置白噪音类型
  void setWhiteNoiseType(WhiteNoiseType? type) {
    _whiteNoiseType = type;
    notifyListeners();
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _audioService?.setVolume(_volume);
    notifyListeners();
  }

  /// 切换白噪音开关
  Future<void> toggleWhiteNoise() async {
    _whiteNoiseEnabled = !_whiteNoiseEnabled;

    if (_whiteNoiseEnabled && _whiteNoiseType != null) {
      await _audioService?.playWhiteNoise(_whiteNoiseType!);
    } else {
      await _audioService?.stopWhiteNoise();
    }

    notifyListeners();
  }

  // ===== 计时器控制 =====
  /// 开始专注
  Future<void> startFocus() async {
    if (_timerState == TimerState.running) return;

    // 启用屏幕常亮
    try {
      await WakelockPlus.enable();
      debugPrint('屏幕常亮已启用');
    } catch (e) {
      debugPrint('启用屏幕常亮失败: $e');
    }

    // 启动白噪音
    if (_whiteNoiseEnabled && _whiteNoiseType != null) {
      await _audioService?.playWhiteNoise(_whiteNoiseType!);
    }

    // 创建计时器
    _timer = TimerUtils(
      onTick: (elapsed) {
        _elapsedSeconds = elapsed;
        notifyListeners();
      },
      onComplete: () {
        _onFocusComplete();
      },
    );

    // 根据模式启动计时
    if (_mode == FocusMode.countdown) {
      _timer!.startCountdown(_targetMinutes * 60);
    } else {
      _timer!.startStopwatch();
    }

    _timerState = TimerState.running;
    notifyListeners();
  }

  /// 暂停专注
  void pauseFocus() {
    if (_timerState != TimerState.running) return;

    _timer?.pause();
    _timerState = TimerState.paused;

    // 暂停白噪音
    _audioService?.pauseWhiteNoise();

    notifyListeners();
  }

  /// 恢复专注
  void resumeFocus() {
    if (_timerState != TimerState.paused) return;

    _timer?.resume();
    _timerState = TimerState.running;

    // 恢复白噪音
    if (_whiteNoiseEnabled && _whiteNoiseType != null) {
      _audioService?.resumeWhiteNoise();
    }

    notifyListeners();
  }

  /// 停止专注（手动停止）
  Future<void> stopFocus() async {
    if (_timerState == TimerState.idle) return;

    // 停止计时器
    _timer?.stop(forced: true);

    // 保存专注记录（至少 1 分钟才保存）
    if (_elapsedSeconds >= 60) {
      await _saveFocusRecord();
    }

    // 重置状态
    await _resetState();
  }

  /// 专注完成回调
  Future<void> _onFocusComplete() async {
    _timerState = TimerState.completed;
    notifyListeners();

    // 播放完成提示音
    await _audioService?.playCompletionSound();

    // 保存专注记录
    await _saveFocusRecord();

    // 自动完成关联习惯打卡（由 UI 层调用 CheckInProvider）
    if (_linkedHabit != null) {
      debugPrint('专注完成，准备自动打卡习惯: ${_linkedHabit!.name}');
    }

    // 重置状态（延迟执行，让 UI 有时间处理完成事件）
    await Future.delayed(const Duration(milliseconds: 500));
    await _resetState();
  }

  /// 保存专注记录
  Future<void> _saveFocusRecord() async {
    try {
      final uuid = Uuid();
      final now = DateTime.now();
      final record = FocusRecord(
        id: uuid.v4(),
        mode: _mode,
        duration: _elapsedSeconds,
        targetDuration: _mode == FocusMode.countdown ? _targetMinutes * 60 : null,
        habitId: _linkedHabit?.id,
        whiteNoiseType: _whiteNoiseType,
        startTime: now.subtract(Duration(seconds: _elapsedSeconds)),
        endTime: now,
        createdAt: now,
      );

      final box = StorageService.focusRecordBox;
      await box.put(record.id, record);
      _focusRecords.add(record);
      notifyListeners();

      debugPrint('专注记录已保存: ${record.id}, 时长: ${record.formattedDuration}');
    } catch (e) {
      debugPrint('保存专注记录失败: $e');
    }
  }

  /// 重置状态
  Future<void> _resetState() async {
    // 禁用屏幕常亮
    try {
      await WakelockPlus.disable();
      debugPrint('屏幕常亮已禁用');
    } catch (e) {
      debugPrint('禁用屏幕常亮失败: $e');
    }

    // 停止白噪音
    await _audioService?.stopWhiteNoise();

    // 重置计时器
    _timer?.dispose();
    _timer = null;
    _elapsedSeconds = 0;
    _timerState = TimerState.idle;

    notifyListeners();
  }

  /// 应用从后台恢复时同步计时
  void syncFromBackground() {
    if (_timerState == TimerState.running) {
      _timer?.syncFromBackground();
      notifyListeners();
    }
  }

  /// 获取某日期的所有专注记录
  List<FocusRecord> getRecordsByDate(DateTime date) {
    return _focusRecords.where((r) => r.isOnDate(date)).toList();
  }

  /// 获取某习惯的所有专注记录
  List<FocusRecord> getRecordsByHabit(String habitId) {
    return _focusRecords.where((r) => r.habitId == habitId).toList();
  }

  @override
  void dispose() {
    _timer?.dispose();
    _audioService?.dispose();
    super.dispose();
  }
}