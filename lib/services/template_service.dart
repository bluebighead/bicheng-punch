import '../models/habit_model.dart';

/// 备考模板库服务
///
/// 内置 4 套官方备考模板，用户首次进入首页时引导选择备考类型，
/// 一键添加对应习惯，也可自定义添加。
class TemplateService {
  TemplateService._();

  /// 考研通用模板：英语单词、数学刷题、专业课复习、政治背诵
  static List<HabitTemplate> getKaoyanTemplates() {
    return [
      HabitTemplate(
        name: '英语单词',
        icon: 'menu_book',
        color: 0xFF6B8E9F, // 莫兰迪蓝
        examCategory: ExamCategory.kaoyan,
        frequencyType: FrequencyType.daily,
        description: '每日背诵单词，稳步积累',
      ),
      HabitTemplate(
        name: '数学刷题',
        icon: 'calculate',
        color: 0xFF9DB4A0, // 柔和绿
        examCategory: ExamCategory.kaoyan,
        frequencyType: FrequencyType.daily,
        description: '每日练习数学题目',
      ),
      HabitTemplate(
        name: '专业课复习',
        icon: 'school',
        color: 0xFFC9A876, // 温暖琥珀
        examCategory: ExamCategory.kaoyan,
        frequencyType: FrequencyType.daily,
        description: '专业课知识点巩固',
      ),
      HabitTemplate(
        name: '政治背诵',
        icon: 'article',
        color: 0xFF7A8B99, // 石板灰
        examCategory: ExamCategory.kaoyan,
        frequencyType: FrequencyType.daily,
        description: '政治核心考点记忆',
      ),
    ];
  }

  /// 考公通用模板：行测刷题、申论积累、常识背诵
  static List<HabitTemplate> getKaogongTemplates() {
    return [
      HabitTemplate(
        name: '行测刷题',
        icon: 'quiz',
        color: 0xFF6B8E9F,
        examCategory: ExamCategory.kaogong,
        frequencyType: FrequencyType.daily,
        description: '每日行测题目练习',
      ),
      HabitTemplate(
        name: '申论积累',
        icon: 'edit_note',
        color: 0xFF9DB4A0,
        examCategory: ExamCategory.kaogong,
        frequencyType: FrequencyType.weeklyX,
        weeklyCount: 5,
        description: '申论素材与范文积累',
      ),
      HabitTemplate(
        name: '常识背诵',
        icon: 'lightbulb',
        color: 0xFFC9A876,
        examCategory: ExamCategory.kaogong,
        frequencyType: FrequencyType.daily,
        description: '常识判断知识点记忆',
      ),
    ];
  }

  /// 教资通用模板：科目一背诵、科目二刷题、教案练习
  static List<HabitTemplate> getJiaozhiTemplates() {
    return [
      HabitTemplate(
        name: '科目一背诵',
        icon: 'psychology',
        color: 0xFF6B8E9F,
        examCategory: ExamCategory.jiaozhi,
        frequencyType: FrequencyType.daily,
        description: '综合素质知识点',
      ),
      HabitTemplate(
        name: '科目二刷题',
        icon: 'fact_check',
        color: 0xFF9DB4A0,
        examCategory: ExamCategory.jiaozhi,
        frequencyType: FrequencyType.daily,
        description: '教育知识与能力练习',
      ),
      HabitTemplate(
        name: '教案练习',
        icon: 'description',
        color: 0xFFC9A876,
        examCategory: ExamCategory.jiaozhi,
        frequencyType: FrequencyType.weeklyX,
        weeklyCount: 3,
        description: '教案设计与练习',
      ),
    ];
  }

  /// 四六级模板：单词背诵、听力练习、阅读刷题
  static List<HabitTemplate> getCetTemplates() {
    return [
      HabitTemplate(
        name: '单词背诵',
        icon: 'translate',
        color: 0xFF6B8E9F,
        examCategory: ExamCategory.cet4cet6,
        frequencyType: FrequencyType.daily,
        description: '四六级核心词汇',
      ),
      HabitTemplate(
        name: '听力练习',
        icon: 'headphones',
        color: 0xFF9DB4A0,
        examCategory: ExamCategory.cet4cet6,
        frequencyType: FrequencyType.weeklyX,
        weeklyCount: 5,
        description: '听力真题训练',
      ),
      HabitTemplate(
        name: '阅读刷题',
        icon: 'auto_stories',
        color: 0xFFC9A876,
        examCategory: ExamCategory.cet4cet6,
        frequencyType: FrequencyType.weeklyX,
        weeklyCount: 4,
        description: '阅读理解练习',
      ),
    ];
  }

  /// 根据备考类型获取对应模板列表
  static List<HabitTemplate> getTemplatesByCategory(ExamCategory category) {
    switch (category) {
      case ExamCategory.kaoyan:
        return getKaoyanTemplates();
      case ExamCategory.kaogong:
        return getKaogongTemplates();
      case ExamCategory.jiaozhi:
        return getJiaozhiTemplates();
      case ExamCategory.cet4cet6:
        return getCetTemplates();
      case ExamCategory.custom:
        return []; // 自定义类型无预设模板
    }
  }

  /// 将模板转换为 Habit 实例（用于一键添加）
  static Habit templateToHabit(HabitTemplate template, String id) {
    return Habit(
      id: id,
      name: template.name,
      icon: template.icon,
      color: template.color,
      examCategory: template.examCategory,
      frequencyType: template.frequencyType,
      weeklyCount: template.weeklyCount ?? 7,
      createdAt: DateTime.now(),
      isActive: true,
    );
  }
}

/// 习惯模板数据结构（仅用于展示，不持久化）
class HabitTemplate {
  const HabitTemplate({
    required this.name,
    required this.icon,
    required this.color,
    required this.examCategory,
    required this.frequencyType,
    this.weeklyCount,
    this.description,
  });

  final String name;
  final String icon;
  final int color;
  final ExamCategory examCategory;
  final FrequencyType frequencyType;
  final int? weeklyCount;
  final String? description;
}