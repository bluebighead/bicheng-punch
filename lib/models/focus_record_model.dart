import 'package:hive/hive.dart';

/// 专注模式枚举
enum FocusMode {
  countdown, // 倒计时（番茄钟模式）
  stopwatch, // 正计时（自由模式）
}

/// 白噪音类型枚举
enum WhiteNoiseType {
  rain, // 雨声
  cafe, // 咖啡馆
  music, // 纯音乐
}

/// 专注记录模型
///
/// 核心属性：
/// - id：唯一标识，UUID
/// - mode：专注模式（正计时/倒计时）
/// - duration：专注时长（秒）
/// - targetDuration：目标时长（秒），倒计时模式有效
/// - habitId：关联习惯 ID，可选
/// - whiteNoiseType：白噪音类型，可选
/// - startTime：开始时间
/// - endTime：结束时间
/// - createdAt：记录创建时间
class FocusRecord {
  FocusRecord({
    required this.id,
    required this.mode,
    required this.duration,
    this.targetDuration,
    this.habitId,
    this.whiteNoiseType,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  final String id;
  final FocusMode mode;
  final int duration; // 秒
  final int? targetDuration; // 秒
  final String? habitId; // 关联的习惯 ID
  final WhiteNoiseType? whiteNoiseType;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  /// 获取格式化的时长字符串（HH:MM:SS）
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取简洁的时长字符串（H时M分 或 M分S秒）
  String get shortDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '$hours时$minutes分';
    } else if (minutes > 0) {
      return '$minutes分$seconds秒';
    } else {
      return '$seconds秒';
    }
  }

  /// 判断是否为今日专注记录
  bool isToday() {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// 判断是否在指定日期
  bool isOnDate(DateTime date) {
    return startTime.year == date.year &&
        startTime.month == date.month &&
        startTime.day == date.day;
  }
}

/// 专注结束铃声类型枚举
///
/// 不持久化到数据库，仅内存态存储。
/// 音频文件需放置到 assets/audio/ 目录下。
enum RingtoneType {
  classic,   // 经典提示音 -> complete.mp3
  gentle,    // 轻柔铃声 -> gentle.mp3
  digital,   // 数字闹铃 -> digital.mp3
  nature,    // 自然风铃 -> nature.mp3
}

/// FocusRecord Hive TypeAdapter
class FocusRecordAdapter extends TypeAdapter<FocusRecord> {
  @override
  final int typeId = 2; // Hive 类型 ID，需唯一（Habit=0, CheckIn=1, FocusRecord=2）

  @override
  FocusRecord read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };

      return FocusRecord(
        id: fields[0] as String,
        mode: FocusMode.values[fields[1] as int],
        duration: fields[2] as int,
        targetDuration: fields[3] as int?,
        habitId: fields[4] as String?,
        whiteNoiseType: fields[5] != null
            ? WhiteNoiseType.values[fields[5] as int]
            : null,
        startTime: fields[6] as DateTime,
        endTime: fields[7] as DateTime,
        createdAt: fields[8] as DateTime,
      );
    } catch (e) {
      // 容错：读取失败时返回默认记录
      final now = DateTime.now();
      return FocusRecord(
        id: 'error_recovery',
        mode: FocusMode.countdown,
        duration: 0,
        startTime: now,
        endTime: now,
        createdAt: now,
      );
    }
  }

  @override
  void write(BinaryWriter writer, FocusRecord obj) {
    writer
      ..writeByte(9) // 字段数量
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.mode.index)
      ..writeByte(2)..write(obj.duration)
      ..writeByte(3)..write(obj.targetDuration)
      ..writeByte(4)..write(obj.habitId)
      ..writeByte(5)..write(obj.whiteNoiseType?.index)
      ..writeByte(6)..write(obj.startTime)
      ..writeByte(7)..write(obj.endTime)
      ..writeByte(8)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}