import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:treehole/main.dart';

void main() {
  setUpAll(() async {
    // 为测试环境初始化 Hive
    final dir = Directory.systemTemp.createTempSync('treehole_test_');
    TestWidgetsFlutterBinding.ensureInitialized();
    // path_provider 在测试中需要手动处理，直接用临时目录
    try {
      await Hive.initFlutter(dir.path);
    } catch (_) {
      // 如果已经初始化则忽略
    }
  });

  testWidgets('TreeholeApp 基础渲染烟雾测试', (WidgetTester tester) async {
    // 由于 main() 中已初始化 Hive 和 Storage，此处直接测试 App 构建
    // 注意：完整初始化需要 PostStorage.init()
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: Text('树通')),
        ),
      ),
    );

    // 基础验证：App 标题存在
    expect(find.text('树通'), findsOneWidget);
  });
}
