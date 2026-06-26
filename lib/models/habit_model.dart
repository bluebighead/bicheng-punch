import 'package:hive/hive.dart';

/// 备考分类枚举
enum ExamCategory {
  kaoyan, // 考研
  kaogong, // 考公
  jiaozhi, // 教资
  cet4cet6, // 四六级
  custom, // 自定义
}

/// 打卡频率类型枚举
enum FrequencyType {
  daily, // 每日
  weeklyX, // 每周 X 次
  customDays, // 自定义日期（周一/周三/周五等）
}

/// 习惯模型
///
/// 核心属性：
/// - id：唯一标识，UUID
/// - name：习惯名称
/// - icon：图标标识（Material Icons name）
/// - color：习惯颜色（存储为 int）
/// - examCategory：备考分类
/// - frequencyType：打卡频率类型
/// - weeklyCount：每周打卡次数（仅 weeklyX 类型有效）
/// - customDays：自定义打卡日期（仅 customDays 类型，存储 weekday 列表 1-7）
/// - createdAt：创建时间
/// - isActive：是否启用
class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.examCategory,
    required this.frequencyType,
    this.weeklyCount = 7,
    this.customDays = const [1, 2, 3, 4, 5, 6, 7],
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String icon; // Material Icon 名称，如 'book', 'calculate', 'fitness_center'
  final int color; // 颜色值，如 0xFF6B8E9F
  final ExamCategory examCategory;
  final FrequencyType frequencyType;
  final int weeklyCount; // 每周打卡次数，默认 7（每日）
  final List<int> customDays; // 自定义打卡日期（1=周一，7=周日）
  final DateTime createdAt;
  final bool isActive;

  /// 判断某天是否需要打卡（根据频率规则）
  bool shouldCheckInOn(DateTime date) {
    if (!isActive) return false;

    switch (frequencyType) {
      case FrequencyType.daily:
        return true;
      case FrequencyType.weeklyX:
        // weeklyX 类型：每周需打卡 X 次，但具体哪天用户自己安排
        // 这里不做强制限制，用户可在任意日期打卡
        return true;
      case FrequencyType.customDays:
        final weekday = date.weekday; // 1=周一，7=周日
        return customDays.contains(weekday);
    }
  }
}

/// Habit Hive TypeAdapter（手动编写，避免 build_runner 复杂度）
class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0; // Hive 类型 ID，需唯一

  @override
  Habit read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{
        for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
      };

      return Habit(
        id: fields[0] as String,
        name: fields[1] as String,
        icon: fields[2] as String,
        color: fields[3] as int,
        examCategory: ExamCategory.values[fields[4] as int],
        frequencyType: FrequencyType.values[fields[5] as int],
        weeklyCount: (fields[6] ?? 7) as int,
        customDays: (fields[7] as List?)?.cast<int>() ?? const [1, 2, 3, 4, 5, 6, 7],
        createdAt: fields[8] as DateTime,
        isActive: fields[9] as bool? ?? true,
      );
    } catch (e) {
      // 容错：读取失败时返回默认习惯，避免数据损坏导致崩溃
      return Habit(
        id: 'error_recovery',
        name: '数据异常',
        icon: 'error_outline',
        color: 0xFF6B8E9F,
        examCategory: ExamCategory.custom,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(10) // 字段数量
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.icon)
      ..writeByte(3)..write(obj.color)
      ..writeByte(4)..write(obj.examCategory.index)
      ..writeByte(5)..write(obj.frequencyType.index)
      ..writeByte(6)..write(obj.weeklyCount)
      ..writeByte(7)..write(obj.customDays)
      ..writeByte(8)..write(obj.createdAt)
      ..writeByte(9)..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}