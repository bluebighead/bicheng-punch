import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/focus_record_model.dart';

/// 白噪音音频服务
///
/// 职责：
/// 1. 播放/暂停/停止白噪音
/// 2. 调节音量
/// 3. 循环播放
/// 4. 播放完成提示音
class AudioService {
  AudioService._();

  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;

  final AudioPlayer _whiteNoisePlayer = AudioPlayer();
  final AudioPlayer _completionPlayer = AudioPlayer();

  WhiteNoiseType? _currentNoise;
  double _volume = 0.5; // 默认音量 50%
  bool _isPlaying = false;

  /// 提示音播放完成的回调（由 FocusProvider 设置，用于重置试听状态）
  VoidCallback? onCompletionSoundComplete;

  /// 当前播放的白噪音类型
  WhiteNoiseType? get currentNoise => _currentNoise;

  /// 当前音量（0.0 - 1.0）
  double get volume => _volume;

  /// 是否正在播放
  bool get isPlaying => _isPlaying;

  /// 白噪音音频资源映射
  static const Map<WhiteNoiseType, String> _noiseAssets = {
    WhiteNoiseType.rain: 'assets/audio/rain.mp3',
    WhiteNoiseType.cafe: 'assets/audio/cafe.mp3',
    WhiteNoiseType.music: 'assets/audio/music.mp3',
  };

  /// 铃声音频资源映射
  static const Map<RingtoneType, String> _ringtoneAssets = {
    RingtoneType.classic: 'assets/audio/complete.mp3',
    RingtoneType.gentle: 'assets/audio/gentle.mp3',
    RingtoneType.digital: 'assets/audio/digital.mp3',
    RingtoneType.nature: 'assets/audio/nature.mp3',
  };

  /// 铃声名称映射（用于 UI 显示）
  static const Map<RingtoneType, String> ringtoneNames = {
    RingtoneType.classic: '经典提示音',
    RingtoneType.gentle: '轻柔铃声',
    RingtoneType.digital: '数字闹铃',
    RingtoneType.nature: '自然风铃',
  };

  /// 铃声图标映射（用于 UI 显示）
  static const Map<RingtoneType, IconData> ringtoneIcons = {
    RingtoneType.classic: Icons.notifications_active,
    RingtoneType.gentle: Icons.music_note,
    RingtoneType.digital: Icons.alarm,
    RingtoneType.nature: Icons.forest,
  };

  /// 初始化音频服务
  Future<void> init() async {
    // 设置循环播放
    await _whiteNoisePlayer.setReleaseMode(ReleaseMode.loop);

    // 设置默认音量
    await _whiteNoisePlayer.setVolume(_volume);
    await _completionPlayer.setVolume(0.7);

    // 监听提示音播放完成事件，通知上层重置试听状态
    _completionPlayer.onPlayerComplete.listen((_) {
      onCompletionSoundComplete?.call();
    });

    debugPrint('AudioService 初始化完成');
  }

  /// 播放白噪音
  ///
  /// 如果指定的白噪音已经在播放，则不做任何操作
  Future<void> playWhiteNoise(WhiteNoiseType type) async {
    if (_currentNoise == type && _isPlaying) {
      debugPrint('白噪音已播放: $type');
      return;
    }

    try {
      // 停止当前播放
      await stopWhiteNoise();

      // 播放新的白噪音
      final asset = _noiseAssets[type]!;
      await _whiteNoisePlayer.setSource(AssetSource(asset.replaceFirst('assets/', '')));
      await _whiteNoisePlayer.setVolume(_volume);
      await _whiteNoisePlayer.resume();

      _currentNoise = type;
      _isPlaying = true;
      debugPrint('开始播放白噪音: $type');
    } catch (e) {
      debugPrint('播放白噪音失败: $e (资源文件可能不存在)');
      // 降级处理：标记为播放但实际无声音，等待资源文件就绪
      _currentNoise = type;
      _isPlaying = true;
    }
  }

  /// 暂停白噪音
  Future<void> pauseWhiteNoise() async {
    if (!_isPlaying) return;

    try {
      await _whiteNoisePlayer.pause();
      _isPlaying = false;
      debugPrint('暂停白噪音');
    } catch (e) {
      debugPrint('暂停白噪音失败: $e');
    }
  }

  /// 恢复播放白噪音
  Future<void> resumeWhiteNoise() async {
    if (_isPlaying || _currentNoise == null) return;

    try {
      await _whiteNoisePlayer.resume();
      _isPlaying = true;
      debugPrint('恢复播放白噪音');
    } catch (e) {
      debugPrint('恢复白噪音失败: $e');
    }
  }

  /// 停止白噪音
  Future<void> stopWhiteNoise() async {
    try {
      await _whiteNoisePlayer.stop();
      _isPlaying = false;
      _currentNoise = null;
      debugPrint('停止白噪音');
    } catch (e) {
      debugPrint('停止白噪音失败: $e');
    }
  }

  /// 设置音量（0.0 - 1.0）
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _whiteNoisePlayer.setVolume(_volume);
      debugPrint('设置音量: ${(_volume * 100).toInt()}%');
    } catch (e) {
      debugPrint('设置音量失败: $e');
    }
  }

  /// 播放完成提示音
  ///
  /// [ringtone] 可选，指定铃声类型，默认为经典提示音
  Future<void> playCompletionSound([RingtoneType ringtone = RingtoneType.classic]) async {
    try {
      await _completionPlayer.stop();

      final asset = _ringtoneAssets[ringtone]!;
      await _completionPlayer.setSource(
        AssetSource(asset.replaceFirst('assets/', '')),
      );
      await _completionPlayer.setVolume(0.7);
      await _completionPlayer.resume();
      debugPrint('播放完成提示音: ${ringtone.name}');
    } catch (e) {
      debugPrint('播放完成提示音失败: $e (资源文件可能不存在)');
      // 降级：如果指定铃声不存在，尝试播放默认铃声
      if (ringtone != RingtoneType.classic) {
        debugPrint('降级播放默认提示音');
        await playCompletionSound(RingtoneType.classic);
      }
    }
  }

  /// 从本地文件播放完成提示音（自定义铃声）
  ///
  /// [filePath] 本地音频文件的绝对路径
  Future<void> playCompletionSoundFromFile(String filePath) async {
    try {
      await _completionPlayer.stop();
      await _completionPlayer.setSource(DeviceFileSource(filePath));
      await _completionPlayer.setVolume(0.7);
      await _completionPlayer.resume();
      debugPrint('播放自定义铃声: $filePath');
    } catch (e) {
      debugPrint('播放自定义铃声失败: $e');
      // 降级播放默认提示音
      await playCompletionSound(RingtoneType.classic);
    }
  }

  /// 停止预览播放
  Future<void> stopPreview() async {
    try {
      await _completionPlayer.stop();
      debugPrint('停止预览播放');
    } catch (e) {
      debugPrint('停止预览播放失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _whiteNoisePlayer.dispose();
    await _completionPlayer.dispose();
    debugPrint('AudioService 资源已释放');
  }
}