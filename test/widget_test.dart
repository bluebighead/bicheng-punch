// 基础冒烟测试：验证应用根 Widget 可正常构建
//
// 第一阶段：仅校验主框架 Shell 启动无异常、底部导航栏渲染。

import 'package:flutter_test/flutter_test.dart';

import 'package:kaobei_punch/main.dart';

void main() {
  testWidgets('应用启动冒烟测试', (WidgetTester tester) async {
    // 构建根 Widget 并触发一帧
    await tester.pumpWidget(const KaobeiPunchApp());

    // 验证底部导航栏 5 个标签存在
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('专注'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('模板'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
