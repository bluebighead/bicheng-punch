/// 白名单应用数据模型
///
/// 用于专注严格模式下允许用户临时使用的应用。
/// 仅持久化包名与应用名称，图标按需通过原生 MethodChannel 获取，
/// 避免在 Hive 中存储大量图标字节。
class WhitelistApp {
  const WhitelistApp({
    required this.packageName,
    required this.label,
  });

  /// 应用包名（如 com.tencent.mm），唯一标识
  final String packageName;

  /// 应用显示名称（如 微信）
  final String label;

  /// 转 JSON（用于持久化到 config_box）
  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'label': label,
      };

  /// 从 JSON 构造
  factory WhitelistApp.fromJson(Map<String, dynamic> json) {
    return WhitelistApp(
      packageName: json['packageName'] as String,
      label: json['label'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhitelistApp && packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}
