import 'package:hive/hive.dart';

/// 打卡记录模型
///
/// 核心属性：
/// - id：唯一标识，UUID
/// - habitId：对应习惯的 id
/// - date：打卡日期（存储为 DateTime，仅用年月日部分）
/// - note：文字备注，可选
/// - imagePath：图片路径，可选（最多1张）
/// - focusDuration：专注时长（分钟），可选
/// - isMakeup：是否为补签
/// - createdAt：打卡记录创建时间
class CheckIn {
  CheckIn({
    required this.id,
    required this.habitId,
    required this.date,
    this.note,
    this.imagePath,
    this.focusDuration,
    this.isMakeup = false,
    required this.createdAt,
  });

  final String id;
  final String habitId;
  final DateTime date; // 打卡日期（年月日）
  final String? note; // 备注
  final String? imagePath; // 图片路径
  final int? focusDuration; // 专注时长（分钟）
  final bool isMakeup; // 是否补签
  final DateTime createdAt; // 记录创建时间

  /// 获取日期的唯一标识字符串（用于查询某日的打卡记录）
  String dateKey() {
    return '${date.year}-${date.month}-${date.day}';
  }

  /// 判断是否为今日打卡
  bool isToday() {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// CheckIn Hive TypeAdapter
class CheckInAdapter extends TypeAdapter<CheckIn> {
  @override
  final int typeId = 1; // Hive 类型 ID，需唯一（不同于 Habit 的 0）

  @override
  CheckIn read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };

      return CheckIn(
        id: fields[0] as String,
        habitId: fields[1] as String,
        date: fields[2] as DateTime,
        note: fields[3] as String?,
        imagePath: fields[4] as String?,
        focusDuration: fields[5] as int?,
        isMakeup: fields[6] as bool? ?? false,
        createdAt: fields[7] as DateTime,
      );
    } catch (e) {
      // 容错：读取失败时返回默认打卡记录
      return CheckIn(
        id: 'error_recovery',
        habitId: 'unknown',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, CheckIn obj) {
    writer
      ..writeByte(8) // 字段数量
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.habitId)
      ..writeByte(2)..write(obj.date)
      ..writeByte(3)..write(obj.note)
      ..writeByte(4)..write(obj.imagePath)
      ..writeByte(5)..write(obj.focusDuration)
      ..writeByte(6)..write(obj.isMakeup)
      ..writeByte(7)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}