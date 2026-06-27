import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/focus_record_model.dart';
import '../models/habit_model.dart';
import '../models/whitelist_app_model.dart';
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

  // ===== 铃声选择（内存态，不存数据库） =====
  RingtoneType _selectedRingtone = RingtoneType.classic; // 默认经典铃声
  String? _customRingtonePath; // 自定义铃声文件路径
  String? _customRingtoneName; // 自定义铃声文件名（UI 显示用）
  bool _isPreviewPlaying = false; // 铃声试听状态

  // ===== 严格模式 =====
  bool _strictMode = false;

  // ===== 白名单应用（严格模式下允许使用的应用，最多 3 个） =====
  static const int kMaxWhitelistApps = 3;
  List<WhitelistApp> _whitelistApps = <WhitelistApp>[];

  // ===== 最近一次完成专注的时长（秒）=====
  // 专注完成后 _onFocusComplete 会延迟自动重置状态（elapsedSeconds 归零），
  // 但完成对话框此时仍可能展示，因此单独保存完成时长供对话框与自动打卡使用。
  int _lastCompletedDuration = 0;

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

  // ===== 铃声与严格模式 Getters =====
  RingtoneType get selectedRingtone => _selectedRingtone;
  String? get customRingtonePath => _customRingtonePath;
  String? get customRingtoneName => _customRingtoneName;
  bool get isPreviewPlaying => _isPreviewPlaying;
  bool get strictMode => _strictMode;

  // ===== 白名单应用 Getters =====
  /// 当前白名单应用列表（不可变视图）
  List<WhitelistApp> get whitelistApps =>
      List.unmodifiable(_whitelistApps);

  /// 白名单是否已满（最多 3 个）
  bool get isWhitelistFull => _whitelistApps.length >= kMaxWhitelistApps;

  /// 白名单应用包名集合（供严格模式 MethodChannel 使用）
  List<String> get whitelistPackageNames =>
      _whitelistApps.map((e) => e.packageName).toList(growable: false);

  /// 最近一次完成专注的时长（秒）
  int get lastCompletedDuration => _lastCompletedDuration;

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

  /// 获取今日专注总时长（秒）
  int get todayFocusSeconds {
    return _focusRecords
        .where((r) => r.isToday())
        .fold(0, (sum, r) => sum + r.duration);
  }

  /// 获取今日专注总时长（格式化：x分x秒）
  String get todayFocusDurationText {
    final seconds = todayFocusSeconds;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes 分 $secs 秒';
    }
    return '$secs 秒';
  }

  // ===== 初始化 =====
  Future<void> _init() async {
    _audioService = AudioService();
    // 注册提示音播放完成回调：试听结束后重置试听状态，避免 UI 卡在"停止试听"
    _audioService!.onCompletionSoundComplete = () {
      if (_isPreviewPlaying) {
        _isPreviewPlaying = false;
        notifyListeners();
      }
    };
    await _audioService!.init();
    await loadFocusRecords();
    _loadWhitelistApps();
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

    if (_whiteNoiseEnabled) {
      // 开启时若无已选类型，默认使用雨声，避免"开关已开但无声音"的问题
      _whiteNoiseType ??= WhiteNoiseType.rain;
      await _audioService?.playWhiteNoise(_whiteNoiseType!);
    } else {
      await _audioService?.stopWhiteNoise();
    }

    notifyListeners();
  }

  // ===== 铃声控制 =====
  /// 设置结束铃声类型（内存态，不存数据库）
  ///
  /// 选择任意内置铃声时都会清除自定义铃声路径：
  /// 播放逻辑为"有自定义路径则优先自定义"，若不清除会导致
  /// 用户选择 classic 后实际仍播放自定义铃声，无法切回内置铃声。
  void setRingtone(RingtoneType type) {
    _selectedRingtone = type;
    _customRingtonePath = null;
    _customRingtoneName = null;
    notifyListeners();
  }

  /// 设置自定义铃声文件路径
  void setCustomRingtonePath(String path, {String? name}) {
    _customRingtonePath = path;
    _customRingtoneName = name ?? _extractFileName(path);
    _selectedRingtone = RingtoneType.classic; // 切回 classic 以使用自定义路径
    notifyListeners();
  }

  /// 从路径中提取文件名
  String _extractFileName(String path) {
    try {
      final segments = path.split(RegExp(r'[/\\]'));
      return segments.isNotEmpty ? segments.last : path;
    } catch (_) {
      return path;
    }
  }

  /// 使用系统文件选择器选取自定义铃声
  ///
  /// 修复问题4：原 FlutterActivity + startActivityForResult 导致选择器立即关闭。
  /// 改用 FlutterFragmentActivity + ActivityResultLauncher 后正常。
  /// 返回值现在为 Map（含 path 和 name），不再是纯字符串。
  Future<void> pickCustomRingtone() async {
    try {
      const channel = MethodChannel('com.kaobei.kaobei_punch/ringtone');
      final result = await channel.invokeMethod<dynamic>('pickRingtone');
      if (result != null) {
        // 兼容 Map（新格式）和 String（旧格式）返回
        if (result is Map) {
          final path = result['path'] as String?;
          final name = result['name'] as String?;
          if (path != null && path.isNotEmpty) {
            setCustomRingtonePath(path, name: name);
          }
        } else if (result is String && result.isNotEmpty) {
          setCustomRingtonePath(result);
        }
      }
    } catch (e) {
      debugPrint('选取自定义铃声失败: $e');
    }
  }

  /// 切换铃声试听（启停）
  Future<void> togglePreview() async {
    if (_isPreviewPlaying) {
      // 停止试听
      await _audioService?.stopPreview();
      _isPreviewPlaying = false;
    } else {
      // 开始试听
      if (_customRingtonePath != null) {
        await _audioService?.playCompletionSoundFromFile(_customRingtonePath!);
      } else {
        await _audioService?.playCompletionSound(_selectedRingtone);
      }
      _isPreviewPlaying = true;
    }
    notifyListeners();
  }

  // ===== 严格模式控制 =====
  /// 切换严格模式
  void toggleStrictMode() {
    _strictMode = !_strictMode;
    notifyListeners();
  }

  /// 设置严格模式
  void setStrictMode(bool value) {
    _strictMode = value;
    notifyListeners();
  }

  // ===== 白名单应用管理 =====

  /// 从持久化存储加载白名单应用列表
  ///
  /// 在 _init 中调用一次。返回值不影响 UI 状态，仅更新内存数据。
  void _loadWhitelistApps() {
    try {
      final rawList = StorageService.getWhitelistApps();
      _whitelistApps = rawList
          .map((json) => WhitelistApp.fromJson(json))
          .toList(growable: true);
      debugPrint('加载 ${_whitelistApps.length} 个白名单应用');
    } catch (e) {
      debugPrint('加载白名单应用失败: $e');
      _whitelistApps = <WhitelistApp>[];
    }
  }

  /// 添加白名单应用
  ///
  /// 成功添加返回 true；若已达上限 [kMaxWhitelistApps] 或已存在同名包则返回 false。
  /// 添加成功后立即持久化，并通知 UI 刷新。
  bool addWhitelistApp(WhitelistApp app) {
    if (_whitelistApps.length >= kMaxWhitelistApps) {
      debugPrint('白名单已满（$kMaxWhitelistApps 个），无法继续添加');
      return false;
    }
    if (_whitelistApps.any((e) => e.packageName == app.packageName)) {
      debugPrint('白名单已存在该应用: ${app.packageName}');
      return false;
    }
    _whitelistApps.add(app);
    _persistWhitelist();
    notifyListeners();
    return true;
  }

  /// 移除白名单应用
  ///
  /// [packageName] 待移除应用的包名
  void removeWhitelistApp(String packageName) {
    final originalLength = _whitelistApps.length;
    _whitelistApps.removeWhere((e) => e.packageName == packageName);
    if (_whitelistApps.length != originalLength) {
      _persistWhitelist();
      notifyListeners();
    }
  }

  /// 清空白名单（用于设置页重置）
  void clearWhitelist() {
    if (_whitelistApps.isEmpty) return;
    _whitelistApps.clear();
    _persistWhitelist();
    notifyListeners();
  }

  /// 将当前白名单写入持久化存储
  void _persistWhitelist() {
    try {
      StorageService.setWhitelistApps(
        _whitelistApps.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('保存白名单应用失败: $e');
    }
  }

  // ===== 计时器控制 =====
  /// 开始专注
  Future<void> startFocus() async {
    if (_timerState == TimerState.running) return;

    // 如果正在试听铃声，先停止
    if (_isPreviewPlaying) {
      await _audioService?.stopPreview();
      _isPreviewPlaying = false;
    }

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
  Future<void> pauseFocus() async {
    if (_timerState != TimerState.running) return;

    _timer?.pause();
    _timerState = TimerState.paused;

    // 暂停白噪音
    _audioService?.pauseWhiteNoise();

    // 停止试听铃声（避免暂停后试听铃声继续播放）
    await _stopPreviewIfNeeded();

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

    // 保存专注记录：无论时长多短都保存（分秒都记录，不丢弃不足 1 分钟的数据）
    if (_elapsedSeconds > 0) {
      await _saveFocusRecord();
    }

    // 重置状态
    await _resetState();
  }

  /// 专注完成回调
  Future<void> _onFocusComplete() async {
    // 保存完成时长，供完成对话框与自动打卡使用
    // （后续 _resetState 会将 _elapsedSeconds 归零，必须提前保存）
    _lastCompletedDuration = _elapsedSeconds;

    _timerState = TimerState.completed;
    notifyListeners();

    // 播放完成提示音前先停止可能正在进行的试听，避免音频重叠
    await _audioService?.stopPreview();

    // 播放完成提示音（优先使用自定义铃声，否则使用用户选择的铃声）
    if (_customRingtonePath != null) {
      await _audioService?.playCompletionSoundFromFile(_customRingtonePath!);
    } else {
      await _audioService?.playCompletionSound(_selectedRingtone);
    }

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

  /// 停止试听铃声并重置试听状态
  ///
  /// 统一在暂停、停止、重置、完成等生命周期点调用，
  /// 避免试听铃声在专注结束后仍继续播放。
  Future<void> _stopPreviewIfNeeded() async {
    if (_isPreviewPlaying) {
      await _audioService?.stopPreview();
      _isPreviewPlaying = false;
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

    // 停止试听铃声
    // 注意：仅当试听正在进行（_isPreviewPlaying=true）时才停止 _completionPlayer。
    // 完成提示音也使用同一个 player，若在此处无条件调用 stopPreview，
    // 会在 _onFocusComplete 触发的延迟 _resetState 中把刚启动的完成提示音一并停止，
    // 导致「倒计时结束不响铃」的问题。完成提示音由完成对话框关闭时显式 stopPreview。
    await _stopPreviewIfNeeded();
    if (_isPreviewPlaying) {
      _isPreviewPlaying = false;
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